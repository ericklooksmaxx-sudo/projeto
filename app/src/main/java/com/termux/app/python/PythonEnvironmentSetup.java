package com.termux.app.python;

import android.app.AlertDialog;
import android.content.Context;
import android.content.res.AssetManager;
import android.widget.Toast;

import androidx.annotation.NonNull;

import com.termux.R;
import com.termux.app.TermuxActivity;
import com.termux.app.overlay.GuiOverlayPermission;
import com.termux.shared.logger.Logger;
import com.termux.shared.termux.TermuxConstants;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

/**
 * Installs the helper commands shipped with the app into the Termux environment and shows the
 * dialog to set up a Python environment (PyTorch, UI libraries, ML runtimes, local LLMs).
 *
 * Everything under {@code assets/termux-gui/} is copied to the Termux prefix:
 * <ul>
 *   <li>{@code bin/*} to {@code $PREFIX/bin} as executables ({@code termux-python-setup},
 *   {@code termux-gui-popup}, {@code termux-gui-run}, {@code termux-llm}).</li>
 *   <li>{@code share/*} to {@code $PREFIX/share/termux-gui} (Python modules and the noVNC page).</li>
 * </ul>
 *
 * The app itself cannot ship these libraries, they are native packages that must match the
 * installed Python, so they are installed with the Termux package manager (and pip for pure Python
 * packages) in a new terminal session where the user can follow the progress.
 */
public final class PythonEnvironmentSetup {

    private static final String LOG_TAG = "PythonEnvironmentSetup";

    private static final String ASSETS_ROOT = "termux-gui";
    private static final String BIN_PREFIX = "bin/";
    private static final String DEFAULT_PACKAGE_PATH = "/data/data/com.termux/files";
    private static final String PACKAGE_NAME_PLACEHOLDER = "@TERMUX_PACKAGE_NAME@";

    public static final String SCRIPT_NAME = "termux-python-setup";
    public static final String SCRIPT_PATH = TermuxConstants.TERMUX_BIN_PREFIX_DIR_PATH + "/" + SCRIPT_NAME;
    public static final String SHARE_DIR_PATH = TermuxConstants.TERMUX_PREFIX_DIR_PATH + "/share/termux-gui";

    /** Profile names passed to the script, in the same order as {@code R.array.python_setup_profiles}. */
    private static final String[] PROFILES = {"ui", "torch", "data", "web", "gui", "ml", "llm"};
    /** Profiles selected by default. */
    private static final boolean[] DEFAULT_SELECTION = {true, true, false, false, false, false, false};
    private static final int GUI_PROFILE_INDEX = 4;

    private PythonEnvironmentSetup() {}

    /**
     * Install or update the helper commands and data files in the Termux prefix. Does nothing if the
     * bootstrap has not been installed yet, and only rewrites files whose content changed.
     *
     * @return {@code true} if everything is installed and up to date.
     */
    public static synchronized boolean installScript(@NonNull Context context) {
        File binDir = new File(TermuxConstants.TERMUX_BIN_PREFIX_DIR_PATH);
        if (!binDir.isDirectory()) return false;

        try {
            List<String> files = new ArrayList<>();
            listAssets(context.getAssets(), ASSETS_ROOT, "", files);
            for (String relativePath : files) {
                boolean executable = relativePath.startsWith(BIN_PREFIX);
                File destination = executable
                    ? new File(binDir, relativePath.substring(BIN_PREFIX.length()))
                    : new File(SHARE_DIR_PATH, relativePath.startsWith("share/") ? relativePath.substring("share/".length()) : relativePath);
                installFile(context, ASSETS_ROOT + "/" + relativePath, destination, executable);
            }
            return true;
        } catch (IOException e) {
            Logger.logStackTraceWithMessage(LOG_TAG, "Failed to install the helper commands", e);
            return false;
        }
    }

    /** Install the helper commands in a background thread. */
    public static void installScriptInBackground(@NonNull Context context) {
        final Context appContext = context.getApplicationContext();
        new Thread(() -> installScript(appContext), "PythonSetupScriptInstaller").start();
    }

    /** Show the dialog to select what to install and start the setup in a new terminal session. */
    public static void showSetupDialog(@NonNull TermuxActivity activity) {
        final boolean[] selection = DEFAULT_SELECTION.clone();

        new AlertDialog.Builder(activity)
            .setTitle(R.string.title_python_setup)
            .setMultiChoiceItems(R.array.python_setup_profiles, selection, (dialog, which, isChecked) -> selection[which] = isChecked)
            .setPositiveButton(R.string.action_python_setup_install, (dialog, which) -> startSetup(activity, selection))
            .setNeutralButton(R.string.action_python_setup_check, (dialog, which) -> startScript(activity, new String[]{"--check"}))
            .setNegativeButton(android.R.string.cancel, null)
            .show();
    }

    /** Menu action: open the settings screen of "Display over other apps" or confirm it is allowed. */
    public static void showFloatingWindowPermission(@NonNull TermuxActivity activity) {
        installScript(activity);
        if (GuiOverlayPermission.requestIfNeeded(activity)) {
            Toast.makeText(activity, R.string.msg_gui_popup_permission_granted, Toast.LENGTH_LONG).show();
        }
    }

    private static void startSetup(@NonNull TermuxActivity activity, @NonNull boolean[] selection) {
        List<String> arguments = new ArrayList<>();
        // The user already confirmed in the dialog.
        arguments.add("--yes");
        for (int i = 0; i < PROFILES.length; i++) {
            if (selection[i]) arguments.add(PROFILES[i]);
        }
        // Only base was selected.
        if (arguments.size() == 1) arguments.add("base");
        // The windowed apps need the permission to draw over other apps, ask while the user is here.
        if (selection[GUI_PROFILE_INDEX]) GuiOverlayPermission.requestIfNeeded(activity);
        startScript(activity, arguments.toArray(new String[0]));
    }

    private static void startScript(@NonNull TermuxActivity activity, @NonNull String[] arguments) {
        if (!installScript(activity)) {
            Toast.makeText(activity, R.string.error_python_setup_script_not_installed, Toast.LENGTH_LONG).show();
            return;
        }
        activity.getTermuxTerminalSessionClient().addNewSession(SCRIPT_PATH, arguments, false,
            activity.getString(R.string.python_setup_session_name));
    }

    // ---- file installation -----------------------------------------------------------------

    /** Collect the paths of all files below {@code path}, relative to {@code root}. */
    private static void listAssets(@NonNull AssetManager assets, @NonNull String root, @NonNull String relative,
                                   @NonNull List<String> out) throws IOException {
        String[] names = assets.list(relative.isEmpty() ? root : root + "/" + relative);
        if (names == null) return;
        for (String name : names) {
            String child = relative.isEmpty() ? name : relative + "/" + name;
            String[] children = assets.list(root + "/" + child);
            if (children != null && children.length > 0) listAssets(assets, root, child, out);
            else out.add(child);
        }
    }

    private static void installFile(@NonNull Context context, @NonNull String assetPath, @NonNull File destination,
                                    boolean executable) throws IOException {
        byte[] content = adaptToPackage(readAsset(context, assetPath));
        File parent = destination.getParentFile();
        if (parent != null && !parent.isDirectory() && !parent.mkdirs() && !parent.isDirectory())
            throw new IOException("Failed to create " + parent);

        if (destination.isFile() && destination.canRead() && Arrays.equals(content, readFile(destination))
            && (!executable || destination.canExecute())) return;

        // Write to a temporary file first so that a running script is never partially overwritten.
        File temp = new File(parent, "." + destination.getName() + ".tmp");
        try (FileOutputStream out = new FileOutputStream(temp)) {
            out.write(content);
        }
        // Only the Termux user may access it (0700 for commands, 0600 for data).
        //noinspection ResultOfMethodCallIgnored
        temp.setReadable(false, false);
        //noinspection ResultOfMethodCallIgnored
        temp.setWritable(false, false);
        //noinspection ResultOfMethodCallIgnored
        temp.setExecutable(false, false);
        if (!temp.setReadable(true, true) || !temp.setWritable(true, true) || (executable && !temp.setExecutable(true, true))) {
            //noinspection ResultOfMethodCallIgnored
            temp.delete();
            throw new IOException("Failed to set permissions of " + temp);
        }
        if (!temp.renameTo(destination)) {
            //noinspection ResultOfMethodCallIgnored
            temp.delete();
            throw new IOException("Failed to move " + temp + " to " + destination);
        }
        Logger.logInfo(LOG_TAG, "Installed " + destination);
    }

    /** The files are written for the default "com.termux" package, use the actual values for forks. */
    @NonNull
    private static byte[] adaptToPackage(@NonNull byte[] content) {
        String text = new String(content, StandardCharsets.UTF_8);
        String adapted = text
            .replace(DEFAULT_PACKAGE_PATH, TermuxConstants.TERMUX_FILES_DIR_PATH)
            .replace(PACKAGE_NAME_PLACEHOLDER, TermuxConstants.TERMUX_PACKAGE_NAME);
        return adapted.equals(text) ? content : adapted.getBytes(StandardCharsets.UTF_8);
    }

    @NonNull
    private static byte[] readAsset(@NonNull Context context, @NonNull String assetPath) throws IOException {
        try (InputStream in = context.getAssets().open(assetPath)) {
            return readFully(in);
        }
    }

    @NonNull
    private static byte[] readFile(@NonNull File file) throws IOException {
        try (InputStream in = new FileInputStream(file)) {
            return readFully(in);
        }
    }

    @NonNull
    private static byte[] readFully(@NonNull InputStream in) throws IOException {
        try (ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            byte[] buffer = new byte[8192];
            int read;
            while ((read = in.read(buffer)) != -1) out.write(buffer, 0, read);
            return out.toByteArray();
        }
    }

}
