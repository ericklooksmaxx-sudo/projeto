package com.termux.app.python;

import android.content.Context;
import android.widget.Toast;

import androidx.annotation.NonNull;
import android.app.AlertDialog;

import com.termux.R;
import com.termux.app.TermuxActivity;
import com.termux.shared.logger.Logger;
import com.termux.shared.termux.TermuxConstants;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.FileInputStream;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

/**
 * Installs the {@code termux-python-setup} script into {@code $PREFIX/bin} and shows a dialog to
 * set up a Python environment with PyTorch and libraries for building user interfaces (Textual,
 * Rich, prompt_toolkit, urwid, tkinter, PyQt5...).
 *
 * The app itself cannot ship these libraries, they are native packages that must match the
 * installed Python, so they are installed with the Termux package manager (and pip for pure Python
 * packages) in a new terminal session where the user can follow the progress.
 */
public final class PythonEnvironmentSetup {

    private static final String LOG_TAG = "PythonEnvironmentSetup";

    public static final String SCRIPT_NAME = "termux-python-setup";
    public static final String SCRIPT_PATH = TermuxConstants.TERMUX_BIN_PREFIX_DIR_PATH + "/" + SCRIPT_NAME;

    /** Profile names passed to the script, in the same order as {@link R.array#python_setup_profiles}. */
    private static final String[] PROFILES = {"ui", "torch", "data", "web", "gui"};
    /** Profiles selected by default. */
    private static final boolean[] DEFAULT_SELECTION = {true, true, false, false, false};

    private PythonEnvironmentSetup() {}

    /**
     * Install or update the script in {@code $PREFIX/bin}. Does nothing if the bootstrap has not
     * been installed yet or if the script is already up to date.
     *
     * @return {@code true} if the script is installed and up to date.
     */
    public static synchronized boolean installScript(@NonNull Context context) {
        File binDir = new File(TermuxConstants.TERMUX_BIN_PREFIX_DIR_PATH);
        if (!binDir.isDirectory()) return false;

        File script = new File(SCRIPT_PATH);
        File tempScript = new File(binDir, "." + SCRIPT_NAME + ".tmp");
        try {
            // The script is written for the default "com.termux" package, use the actual paths for forks.
            byte[] content = new String(readRawResource(context, R.raw.termux_python_setup), StandardCharsets.UTF_8)
                .replace("/data/data/com.termux/files", TermuxConstants.TERMUX_FILES_DIR_PATH)
                .getBytes(StandardCharsets.UTF_8);
            if (script.isFile() && Arrays.equals(content, readFile(script)) && script.canExecute())
                return true;

            // Write to a temporary file first so that a running script is never partially overwritten.
            try (FileOutputStream out = new FileOutputStream(tempScript)) {
                out.write(content);
            }
            // Only the Termux user may read, write and execute it (0700).
            //noinspection ResultOfMethodCallIgnored
            tempScript.setReadable(false, false);
            //noinspection ResultOfMethodCallIgnored
            tempScript.setWritable(false, false);
            //noinspection ResultOfMethodCallIgnored
            tempScript.setExecutable(false, false);
            if (!tempScript.setReadable(true, true) || !tempScript.setWritable(true, true) ||
                !tempScript.setExecutable(true, true))
                throw new IOException("Failed to set permissions of " + tempScript);
            if (!tempScript.renameTo(script))
                throw new IOException("Failed to move " + tempScript + " to " + script);
            Logger.logInfo(LOG_TAG, "Installed " + SCRIPT_PATH);
            return true;
        } catch (IOException e) {
            Logger.logStackTraceWithMessage(LOG_TAG, "Failed to install " + SCRIPT_PATH, e);
            //noinspection ResultOfMethodCallIgnored
            tempScript.delete();
            return false;
        }
    }

    /** Install the script in a background thread. */
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

    private static void startSetup(@NonNull TermuxActivity activity, @NonNull boolean[] selection) {
        List<String> arguments = new ArrayList<>();
        // The user already confirmed in the dialog.
        arguments.add("--yes");
        for (int i = 0; i < PROFILES.length; i++) {
            if (selection[i]) arguments.add(PROFILES[i]);
        }
        // Only base was selected.
        if (arguments.size() == 1) arguments.add("base");
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

    @NonNull
    private static byte[] readRawResource(@NonNull Context context, int resId) throws IOException {
        try (InputStream in = context.getResources().openRawResource(resId)) {
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
