package com.termux.app.overlay;

import androidx.annotation.Nullable;

import java.net.URI;
import java.net.URISyntaxException;
import java.util.Locale;

/**
 * Rules for what the floating window may show and how windows are named.
 *
 * The floating window is drawn over other apps, so it must never be usable to display arbitrary web
 * content (phishing over a banking app, for example): only plain {@code http} pages served from the
 * device itself are allowed, which is what local GUI servers (noVNC, Flet, llama-server) use.
 */
public final class GuiPopupPolicy {

    public static final String DEFAULT_ID = "default";
    public static final int MAX_URL_LENGTH = 2048;

    private GuiPopupPolicy() {}

    /** Whether {@code url} is an {@code http://127.0.0.1}, {@code http://localhost} or {@code http://[::1]} address. */
    public static boolean isAllowedUrl(@Nullable String url) {
        if (url == null || url.isEmpty() || url.length() > MAX_URL_LENGTH) return false;

        // Spaces, control characters, and non ASCII characters are rejected before parsing: they are
        // handled differently by URI and by WebView, which is how URL filters get bypassed.
        for (int i = 0; i < url.length(); i++) {
            char c = url.charAt(i);
            if (c <= 0x20 || c >= 0x7f) return false;
        }

        final URI uri;
        try {
            uri = new URI(url);
        } catch (URISyntaxException e) {
            return false; // Also rejects backslashes, which WebView treats like slashes.
        }

        if (!"http".equals(uri.getScheme())) return false;
        // "http://127.0.0.1@evil.example/" has user info "127.0.0.1" and host "evil.example".
        if (uri.getRawUserInfo() != null) return false;

        String host = uri.getHost();
        if (host == null) return false;
        host = host.toLowerCase(Locale.ROOT);
        if (!(host.equals("127.0.0.1") || host.equals("localhost") || host.equals("[::1]"))) return false;

        int port = uri.getPort();
        return port == -1 || (port >= 1 && port <= 65535);
    }

    /**
     * @return The window id to use: {@link #DEFAULT_ID} if {@code id} is null or empty, the id itself
     * if it is 1 to 32 letters, digits, "_" or "-", and {@code null} if it is invalid. The id is used
     * as a file name for the state file, so it must not contain path separators.
     */
    @Nullable
    public static String sanitizeId(@Nullable String id) {
        if (id == null || id.isEmpty()) return DEFAULT_ID;
        if (id.length() > 32) return null;
        for (int i = 0; i < id.length(); i++) {
            char c = id.charAt(i);
            boolean valid = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '_' || c == '-';
            if (!valid) return null;
        }
        return id;
    }

    public static int clamp(int value, int min, int max) {
        if (max < min) return min;
        return Math.max(min, Math.min(max, value));
    }

    /** Shorten a title to a reasonable length for the title bar. */
    public static String sanitizeTitle(@Nullable String title, String fallback) {
        if (title == null) return fallback;
        title = title.trim();
        if (title.isEmpty()) return fallback;
        return title.length() > 60 ? title.substring(0, 60) : title;
    }

}
