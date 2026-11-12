package com.termux.app.overlay;

import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.os.Build;
import android.provider.Settings;

import androidx.annotation.NonNull;

import com.termux.shared.logger.Logger;

/** Helpers for the "Display over other apps" (SYSTEM_ALERT_WINDOW) permission used by the floating window. */
public final class GuiOverlayPermission {

    private static final String LOG_TAG = "GuiOverlayPermission";

    private GuiOverlayPermission() {}

    /** Whether the app may draw over other apps. Always true before Android 6, where it is granted at install. */
    public static boolean canDraw(@NonNull Context context) {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(context);
    }

    /** The settings screen where the user can allow the permission for this app. */
    @NonNull
    public static Intent createSettingsIntent(@NonNull Context context) {
        Intent intent = new Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:" + context.getPackageName()));
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        return intent;
    }

    /** Open the settings screen of the permission. */
    public static boolean openSettings(@NonNull Context context) {
        try {
            context.startActivity(createSettingsIntent(context));
            return true;
        } catch (ActivityNotFoundException | SecurityException e) {
            Logger.logStackTraceWithMessage(LOG_TAG, "Failed to open the overlay permission settings", e);
            return false;
        }
    }

    /** Ask for the permission from an activity if it is not granted yet. @return {@code true} if already granted. */
    public static boolean requestIfNeeded(@NonNull Activity activity) {
        if (canDraw(activity)) return true;
        openSettings(activity);
        return false;
    }

}
