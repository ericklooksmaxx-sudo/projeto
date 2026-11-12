package com.termux.app.overlay;

import org.junit.Test;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;

public class GuiPopupPolicyTest {

    @Test
    public void allowsOnlyLoopbackHttpUrls() {
        assertTrue(GuiPopupPolicy.isAllowedUrl("http://127.0.0.1:8080"));
        assertTrue(GuiPopupPolicy.isAllowedUrl("http://127.0.0.1:6080/index.html#pw=a1b2c3d4&mode=scale"));
        assertTrue(GuiPopupPolicy.isAllowedUrl("http://localhost"));
        assertTrue(GuiPopupPolicy.isAllowedUrl("http://LOCALHOST:3000/path?x=1"));
        assertTrue(GuiPopupPolicy.isAllowedUrl("http://[::1]:8000/"));
    }

    @Test
    public void rejectsEverythingElse() {
        assertFalse(GuiPopupPolicy.isAllowedUrl(null));
        assertFalse(GuiPopupPolicy.isAllowedUrl(""));
        assertFalse(GuiPopupPolicy.isAllowedUrl("https://127.0.0.1:8080"));
        assertFalse(GuiPopupPolicy.isAllowedUrl("https://example.com"));
        assertFalse(GuiPopupPolicy.isAllowedUrl("http://example.com"));
        assertFalse(GuiPopupPolicy.isAllowedUrl("file:///data/data/com.termux/files/home/secret"));
        assertFalse(GuiPopupPolicy.isAllowedUrl("content://com.termux.files/data"));
        assertFalse(GuiPopupPolicy.isAllowedUrl("javascript:alert(1)"));
        assertFalse(GuiPopupPolicy.isAllowedUrl("data:text/html,hello"));
        assertFalse(GuiPopupPolicy.isAllowedUrl("about:blank"));
        assertFalse(GuiPopupPolicy.isAllowedUrl("127.0.0.1:8080"));
    }

    @Test
    public void rejectsHostConfusionTricks() {
        // The real host is the part after "@".
        assertFalse(GuiPopupPolicy.isAllowedUrl("http://127.0.0.1@evil.example/"));
        assertFalse(GuiPopupPolicy.isAllowedUrl("http://localhost:80@evil.example/"));
        assertFalse(GuiPopupPolicy.isAllowedUrl("http://user:pass@127.0.0.1/"));
        // Look-alike hosts.
        assertFalse(GuiPopupPolicy.isAllowedUrl("http://127.0.0.1.evil.example/"));
        assertFalse(GuiPopupPolicy.isAllowedUrl("http://localhost.evil.example/"));
        assertFalse(GuiPopupPolicy.isAllowedUrl("http://evil-localhost/"));
        assertFalse(GuiPopupPolicy.isAllowedUrl("http://127.0.0.2/"));
        assertFalse(GuiPopupPolicy.isAllowedUrl("http://0.0.0.0:8080/"));
        assertFalse(GuiPopupPolicy.isAllowedUrl("http://192.168.1.10:8080/"));
        // WebView treats backslash like a slash, URI does not.
        assertFalse(GuiPopupPolicy.isAllowedUrl("http://127.0.0.1\\@evil.example/"));
        assertFalse(GuiPopupPolicy.isAllowedUrl("http://evil.example\\.127.0.0.1/"));
        // Fragment and query tricks do not change the host.
        assertFalse(GuiPopupPolicy.isAllowedUrl("http://evil.example#@127.0.0.1/"));
        assertFalse(GuiPopupPolicy.isAllowedUrl("http://evil.example?127.0.0.1"));
    }

    @Test
    public void rejectsControlCharactersSpacesAndBadPorts() {
        assertFalse(GuiPopupPolicy.isAllowedUrl("http://127.0.0.1:8080/ x"));
        assertFalse(GuiPopupPolicy.isAllowedUrl("http://127.0.0.1:8080/\nhttp://evil.example"));
        assertFalse(GuiPopupPolicy.isAllowedUrl("http://127.0.0.1:8080/\u0000"));
        assertFalse(GuiPopupPolicy.isAllowedUrl("http://127.0.0.1:8080/é"));
        assertFalse(GuiPopupPolicy.isAllowedUrl("http://127.0.0.1:99999/"));
        assertFalse(GuiPopupPolicy.isAllowedUrl("http://127.0.0.1:abc/"));
        assertFalse(GuiPopupPolicy.isAllowedUrl("http://127.0.0.1:0/"));
        StringBuilder longUrl = new StringBuilder("http://127.0.0.1/");
        for (int i = 0; i < GuiPopupPolicy.MAX_URL_LENGTH; i++) longUrl.append('a');
        assertFalse(GuiPopupPolicy.isAllowedUrl(longUrl.toString()));
    }

    @Test
    public void sanitizesIds() {
        assertEquals("default", GuiPopupPolicy.sanitizeId(null));
        assertEquals("default", GuiPopupPolicy.sanitizeId(""));
        assertEquals("tk-demo_1", GuiPopupPolicy.sanitizeId("tk-demo_1"));
        // The id becomes a file name for the state file.
        assertNull(GuiPopupPolicy.sanitizeId("../../etc/passwd"));
        assertNull(GuiPopupPolicy.sanitizeId("a/b"));
        assertNull(GuiPopupPolicy.sanitizeId("a b"));
        assertNull(GuiPopupPolicy.sanitizeId(".."));
        assertNull(GuiPopupPolicy.sanitizeId("a\0b"));
        assertNull(GuiPopupPolicy.sanitizeId("0123456789012345678901234567890123"));
    }

    @Test
    public void titlesAndClamp() {
        assertEquals("fallback", GuiPopupPolicy.sanitizeTitle(null, "fallback"));
        assertEquals("fallback", GuiPopupPolicy.sanitizeTitle("   ", "fallback"));
        assertEquals("My app", GuiPopupPolicy.sanitizeTitle("  My app ", "fallback"));
        assertEquals(60, GuiPopupPolicy.sanitizeTitle(new String(new char[200]).replace('\0', 'x'), "f").length());
        assertEquals(5, GuiPopupPolicy.clamp(1, 5, 10));
        assertEquals(10, GuiPopupPolicy.clamp(50, 5, 10));
        assertEquals(7, GuiPopupPolicy.clamp(7, 5, 10));
        assertEquals(5, GuiPopupPolicy.clamp(7, 5, 3));
    }

}
