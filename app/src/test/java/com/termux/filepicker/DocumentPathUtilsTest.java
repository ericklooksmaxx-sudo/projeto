package com.termux.filepicker;

import org.junit.Test;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;

public class DocumentPathUtilsTest {

    private static final String HOME = "/data/data/com.termux/files/home";

    @Test
    public void normalizeAbsolutePath() {
        assertEquals(HOME, DocumentPathUtils.normalizeAbsolutePath(HOME));
        assertEquals(HOME + "/a", DocumentPathUtils.normalizeAbsolutePath(HOME + "//./a/"));
        assertEquals("/data/data/com.termux/files/usr/etc", DocumentPathUtils.normalizeAbsolutePath(HOME + "/../usr/etc"));
        assertEquals("/", DocumentPathUtils.normalizeAbsolutePath("/../../.."));
        assertNull(DocumentPathUtils.normalizeAbsolutePath("relative/path"));
        assertNull(DocumentPathUtils.normalizeAbsolutePath(null));
        assertNull(DocumentPathUtils.normalizeAbsolutePath(HOME + "/a\0b"));
    }

    @Test
    public void isPathInsideRejectsTraversalAndSiblings() {
        assertTrue(DocumentPathUtils.isPathInside(HOME, HOME));
        assertTrue(DocumentPathUtils.isPathInside(HOME, HOME + "/.bashrc"));
        assertTrue(DocumentPathUtils.isPathInside(HOME + "/dir", HOME + "/dir/sub/../file"));

        // The old startsWith() based isChildDocument() accepted all of these.
        assertFalse(DocumentPathUtils.isPathInside(HOME + "/dir", HOME + "/dir/../.ssh/id_rsa"));
        assertFalse(DocumentPathUtils.isPathInside(HOME + "/dir", HOME + "/dir-other/file"));
        assertFalse(DocumentPathUtils.isPathInside(HOME, HOME + "/../../shared_prefs/x.xml"));
        assertFalse(DocumentPathUtils.isPathInside(HOME, "relative"));
        assertTrue(DocumentPathUtils.isPathInside("/", "/anything"));
    }

    @Test
    public void fileNames() {
        assertTrue(DocumentPathUtils.isValidFileName("model.pt"));
        assertFalse(DocumentPathUtils.isValidFileName(".."));
        assertFalse(DocumentPathUtils.isValidFileName("."));
        assertFalse(DocumentPathUtils.isValidFileName(""));
        assertFalse(DocumentPathUtils.isValidFileName("../../usr/etc/bash.bashrc"));
        assertFalse(DocumentPathUtils.isValidFileName("a/b"));

        assertEquals("bash.bashrc", DocumentPathUtils.sanitizeFileName("../../usr/etc/bash.bashrc"));
        assertEquals("evil.sh", DocumentPathUtils.sanitizeFileName("..\\..\\evil.sh"));
        assertEquals("photo.jpg", DocumentPathUtils.sanitizeFileName("photo.jpg"));
        assertNull(DocumentPathUtils.sanitizeFileName("dir/.."));
        assertNull(DocumentPathUtils.sanitizeFileName(null));
    }

    @Test
    public void fileExtension() {
        assertEquals("jpg", DocumentPathUtils.getFileExtension("IMG.JPG"));
        assertEquals("gz", DocumentPathUtils.getFileExtension("a.tar.gz"));
        assertNull(DocumentPathUtils.getFileExtension("Makefile"));
        assertNull(DocumentPathUtils.getFileExtension("trailing."));
    }

}
