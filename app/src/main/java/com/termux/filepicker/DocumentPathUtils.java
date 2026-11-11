package com.termux.filepicker;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import java.util.ArrayDeque;
import java.util.Deque;

/**
 * Pure path helpers used by {@link TermuxDocumentsProvider} to make sure that document ids received
 * from other apps cannot escape the exposed directory with {@code ..} components, and that names
 * of new documents cannot contain path separators.
 *
 * The checks are lexical (no symlink resolution), so symlinks that the user created inside
 * $HOME (like ~/storage/shared) keep working as before.
 */
public final class DocumentPathUtils {

    private DocumentPathUtils() {}

    /**
     * Lexically normalize an absolute path: collapse duplicate separators and resolve {@code .}
     * and {@code ..} components.
     *
     * @return The normalized path, or {@code null} if the path is null, not absolute or contains a
     * NUL character.
     */
    @Nullable
    public static String normalizeAbsolutePath(@Nullable String path) {
        if (path == null || !path.startsWith("/") || path.indexOf('\0') >= 0) return null;

        Deque<String> parts = new ArrayDeque<>();
        for (String part : path.split("/")) {
            if (part.isEmpty() || part.equals(".")) continue;
            if (part.equals("..")) {
                if (!parts.isEmpty()) parts.removeLast();
                continue;
            }
            parts.addLast(part);
        }

        if (parts.isEmpty()) return "/";
        StringBuilder sb = new StringBuilder();
        for (String part : parts) sb.append('/').append(part);
        return sb.toString();
    }

    /**
     * Check whether {@code childPath} is {@code parentPath} itself or is located inside it, after
     * normalizing both paths. Unlike a plain {@link String#startsWith(String)}, this does not
     * consider {@code /a/bc} to be inside {@code /a/b} and is not fooled by {@code /a/b/../c}.
     */
    public static boolean isPathInside(@Nullable String parentPath, @Nullable String childPath) {
        String parent = normalizeAbsolutePath(parentPath);
        String child = normalizeAbsolutePath(childPath);
        if (parent == null || child == null) return false;
        if (parent.equals(child)) return true;
        String prefix = parent.equals("/") ? "/" : parent + "/";
        return child.startsWith(prefix);
    }

    /**
     * Check whether {@code name} is a valid single file name that can be safely appended to a
     * directory path.
     */
    public static boolean isValidFileName(@Nullable String name) {
        return name != null && !name.isEmpty() && !name.equals(".") && !name.equals("..") &&
            name.indexOf('/') < 0 && name.indexOf('\0') < 0;
    }

    /**
     * Get a safe file name from a name that may be controlled by another app, by keeping only the
     * last path component and replacing characters that are not allowed in file names.
     *
     * @return The sanitized name, or {@code null} if nothing usable remains.
     */
    @Nullable
    public static String sanitizeFileName(@Nullable String name) {
        if (name == null) return null;
        name = name.replace('\0', '_').replace('\\', '/');
        int lastSlash = name.lastIndexOf('/');
        if (lastSlash >= 0) name = name.substring(lastSlash + 1);
        name = name.trim();
        if (!isValidFileName(name)) return null;
        return name;
    }

    /** Get the lower-cased file extension of {@code fileName} without the dot, or {@code null}. */
    @Nullable
    public static String getFileExtension(@NonNull String fileName) {
        int lastDot = fileName.lastIndexOf('.');
        if (lastDot < 0 || lastDot == fileName.length() - 1) return null;
        return fileName.substring(lastDot + 1).toLowerCase(java.util.Locale.ROOT);
    }

}
