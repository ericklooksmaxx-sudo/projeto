package com.termux.app.overlay;

import android.app.Notification;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Intent;
import android.os.Build;
import android.os.IBinder;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.termux.R;
import com.termux.shared.logger.Logger;
import com.termux.shared.notification.NotificationUtils;
import com.termux.shared.termux.TermuxConstants;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Service that owns the floating windows shown by the {@code termux-gui-popup} command.
 *
 * It is not exported, so only commands run inside Termux (which share the app uid, through the
 * {@code am} command) can control it. The state of every window is written to
 * {@code $PREFIX/tmp/termux-gui-popup/<id>.state} ("open", "hidden" or "closed") so that scripts
 * can wait for the user to close a window.
 */
public class GuiOverlayService extends Service implements GuiOverlayWindow.Callback {

    public static final String ACTION_SHOW = "com.termux.app.GUI_POPUP_SHOW";
    public static final String ACTION_HIDE = "com.termux.app.GUI_POPUP_HIDE";
    public static final String ACTION_RESTORE = "com.termux.app.GUI_POPUP_RESTORE";
    public static final String ACTION_FULLSCREEN = "com.termux.app.GUI_POPUP_FULLSCREEN";
    public static final String ACTION_RELOAD = "com.termux.app.GUI_POPUP_RELOAD";
    public static final String ACTION_CLOSE = "com.termux.app.GUI_POPUP_CLOSE";
    public static final String ACTION_CLOSE_ALL = "com.termux.app.GUI_POPUP_CLOSE_ALL";

    public static final String EXTRA_ID = "id";
    public static final String EXTRA_URL = "url";
    public static final String EXTRA_TITLE = "title";
    public static final String EXTRA_WIDTH = "width";
    public static final String EXTRA_HEIGHT = "height";
    public static final String EXTRA_FULLSCREEN = "fullscreen";

    private static final String LOG_TAG = "GuiOverlayService";

    private static final String NOTIFICATION_CHANNEL_ID = "termux_gui_popup_notification_channel";
    private static final int NOTIFICATION_ID = 1340;
    private static final int PERMISSION_NOTIFICATION_ID = 1341;

    private static final int DEFAULT_WIDTH_DP = 360;
    private static final int DEFAULT_HEIGHT_DP = 520;

    private static final String STATE_DIR_PATH = TermuxConstants.TERMUX_TMP_PREFIX_DIR_PATH + "/termux-gui-popup";

    private final Map<String, GuiOverlayWindow> mWindows = new LinkedHashMap<>();

    @Override
    public void onCreate() {
        super.onCreate();
        NotificationUtils.setupNotificationChannel(this, NOTIFICATION_CHANNEL_ID,
            getString(R.string.notification_channel_gui_popup), NotificationManager.IMPORTANCE_LOW);
    }

    @Override
    public int onStartCommand(@Nullable Intent intent, int flags, int startId) {
        // Started with startForegroundService(): must call startForeground() quickly even when
        // there is nothing to show.
        startForeground(NOTIFICATION_ID, buildNotification());

        if (intent != null && intent.getAction() != null) handleIntent(intent);

        if (mWindows.isEmpty()) {
            stopForeground(true);
            stopSelf();
        } else {
            updateNotification();
        }
        return START_NOT_STICKY;
    }

    private void handleIntent(@NonNull Intent intent) {
        final String action = intent.getAction();
        if (ACTION_CLOSE_ALL.equals(action)) {
            closeAll();
            return;
        }

        final String id = GuiPopupPolicy.sanitizeId(intent.getStringExtra(EXTRA_ID));
        if (id == null) {
            Logger.logError(LOG_TAG, "Invalid window id");
            return;
        }

        final GuiOverlayWindow window = mWindows.get(id);
        switch (action) {
            case ACTION_SHOW:
                showWindow(id, window, intent);
                break;
            case ACTION_HIDE:
                if (window != null) window.hide();
                break;
            case ACTION_RESTORE:
                if (window != null) window.restore();
                break;
            case ACTION_FULLSCREEN:
                if (window != null) window.toggleFullscreen();
                break;
            case ACTION_RELOAD:
                if (window != null) window.reload();
                break;
            case ACTION_CLOSE:
                if (window != null) window.close();
                else writeState(id, "closed");
                break;
            default:
                Logger.logError(LOG_TAG, "Unknown action \"" + action + "\"");
        }
    }

    private void showWindow(@NonNull String id, @Nullable GuiOverlayWindow existing, @NonNull Intent intent) {
        final String url = intent.getStringExtra(EXTRA_URL);
        // SECURITY: only pages served from the device itself, see GuiPopupPolicy.
        if (!GuiPopupPolicy.isAllowedUrl(url)) {
            Logger.logError(LOG_TAG, "Refusing to open a url that is not on localhost");
            Toast.makeText(this, R.string.popup_error_url_not_allowed, Toast.LENGTH_LONG).show();
            writeState(id, "closed");
            return;
        }
        final String title = GuiPopupPolicy.sanitizeTitle(intent.getStringExtra(EXTRA_TITLE), id);

        if (existing != null) {
            existing.setTitle(title);
            existing.loadUrl(url);
            return;
        }

        if (!GuiOverlayPermission.canDraw(this)) {
            writeState(id, "closed");
            notifyPermissionMissing();
            return;
        }

        final GuiOverlayWindow window = new GuiOverlayWindow(this, id, this);
        // Put it in the map first: show() reports its state through the callback.
        mWindows.put(id, window);
        try {
            window.show(title, url,
                intent.getIntExtra(EXTRA_WIDTH, DEFAULT_WIDTH_DP), intent.getIntExtra(EXTRA_HEIGHT, DEFAULT_HEIGHT_DP),
                intent.getBooleanExtra(EXTRA_FULLSCREEN, false), mWindows.size() - 1);
        } catch (RuntimeException e) {
            // For example WindowManager.BadTokenException when the permission has been revoked.
            Logger.logStackTraceWithMessage(LOG_TAG, "Failed to show the window \"" + id + "\"", e);
            window.close();
            notifyPermissionMissing();
        }
    }

    private void closeAll() {
        for (GuiOverlayWindow window : new ArrayList<>(mWindows.values())) window.close();
    }

    // ---- GuiOverlayWindow.Callback ---------------------------------------------------------

    @Override
    public void onWindowClosed(@NonNull String id) {
        mWindows.remove(id);
        writeState(id, "closed");
        if (mWindows.isEmpty()) {
            stopForeground(true);
            stopSelf();
        } else {
            updateNotification();
        }
    }

    @Override
    public void onWindowStateChanged(@NonNull String id, @NonNull String state) {
        writeState(id, state);
    }

    // ---- notifications ---------------------------------------------------------------------

    private Notification buildNotification() {
        int count = mWindows.size();
        String text = count == 0 ? getString(R.string.notification_gui_popup_starting)
            : getResources().getQuantityString(R.plurals.notification_gui_popup_windows, count, count);

        Notification.Builder builder = NotificationUtils.geNotificationBuilder(this, NOTIFICATION_CHANNEL_ID,
            Notification.PRIORITY_LOW, getString(R.string.notification_gui_popup_title), text, null, null, null,
            NotificationUtils.NOTIFICATION_MODE_SILENT);
        if (builder == null) return new Notification();
        builder.setShowWhen(false);
        builder.setOngoing(true);
        builder.setSmallIcon(R.drawable.ic_service_notification);
        builder.setColor(0xFF607D8B);

        Intent closeAll = new Intent(this, GuiOverlayService.class).setAction(ACTION_CLOSE_ALL);
        builder.addAction(new Notification.Action.Builder(0, getString(R.string.popup_close_all), createServicePendingIntent(closeAll)).build());
        return builder.build();
    }

    private void updateNotification() {
        NotificationManager manager = NotificationUtils.getNotificationManager(this);
        if (manager != null) manager.notify(NOTIFICATION_ID, buildNotification());
    }

    /**
     * Tell the user that the "Display over other apps" permission is needed. The settings screen is
     * opened directly when Android allows it, and a notification is posted as a fallback because
     * starting activities from the background can be blocked.
     */
    private void notifyPermissionMissing() {
        Toast.makeText(this, R.string.popup_error_permission, Toast.LENGTH_LONG).show();
        if (GuiOverlayPermission.openSettings(this)) return;

        PendingIntent settings = PendingIntent.getActivity(this, 0, GuiOverlayPermission.createSettingsIntent(this),
            PendingIntent.FLAG_UPDATE_CURRENT | (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M ? PendingIntent.FLAG_IMMUTABLE : 0));
        Notification.Builder builder = NotificationUtils.geNotificationBuilder(this, NOTIFICATION_CHANNEL_ID,
            Notification.PRIORITY_DEFAULT, getString(R.string.notification_gui_popup_title),
            getString(R.string.popup_error_permission), null, settings, null, NotificationUtils.NOTIFICATION_MODE_SILENT);
        if (builder == null) return;
        builder.setSmallIcon(R.drawable.ic_service_notification);
        builder.setAutoCancel(true);
        NotificationManager manager = NotificationUtils.getNotificationManager(this);
        if (manager != null) manager.notify(PERMISSION_NOTIFICATION_ID, builder.build());
    }

    private PendingIntent createServicePendingIntent(@NonNull Intent intent) {
        int flags = PendingIntent.FLAG_UPDATE_CURRENT | (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M ? PendingIntent.FLAG_IMMUTABLE : 0);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            return PendingIntent.getForegroundService(this, 0, intent, flags);
        return PendingIntent.getService(this, 0, intent, flags);
    }

    // ---- state files -----------------------------------------------------------------------

    private static void writeState(@NonNull String id, @NonNull String state) {
        File dir = new File(STATE_DIR_PATH);
        if (!dir.isDirectory() && !dir.mkdirs() && !dir.isDirectory()) {
            Logger.logError(LOG_TAG, "Cannot create " + STATE_DIR_PATH);
            return;
        }
        // Write to a temporary file and rename it so readers never see a partial file.
        File tmp = new File(dir, id + ".state.tmp");
        try (FileOutputStream out = new FileOutputStream(tmp)) {
            out.write((state + "\n").getBytes(StandardCharsets.UTF_8));
        } catch (IOException e) {
            Logger.logStackTraceWithMessage(LOG_TAG, "Failed to write the state of \"" + id + "\"", e);
            return;
        }
        if (!tmp.renameTo(new File(dir, id + ".state"))) {
            //noinspection ResultOfMethodCallIgnored
            tmp.delete();
        }
    }

    @Override
    public void onDestroy() {
        closeAll();
        super.onDestroy();
    }

    @Nullable
    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

}
