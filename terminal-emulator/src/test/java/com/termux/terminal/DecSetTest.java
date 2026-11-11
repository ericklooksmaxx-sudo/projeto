package com.termux.terminal;

/**
 * <pre>
 * "CSI ? Pm h", DEC Private Mode Set (DECSET)
 * </pre>
 * <p/>
 * and
 * <p/>
 * <pre>
 * "CSI ? Pm l", DEC Private Mode Reset (DECRST)
 * </pre>
 * <p/>
 * controls various aspects of the terminal
 */
public class DecSetTest extends TerminalTestCase {

	/** DECSET 25, DECTCEM, controls visibility of the cursor. */
	public void testEnableDisableCursor() {
		withTerminalSized(3, 3);
		assertTrue("Initially the cursor should be enabled", mTerminal.isCursorEnabled());
		enterString("\033[?25l"); // Disable Cursor (DECTCEM).
		assertFalse(mTerminal.isCursorEnabled());
		enterString("\033[?25h"); // Enable Cursor (DECTCEM).
		assertTrue(mTerminal.isCursorEnabled());

		enterString("\033[?25l"); // Disable Cursor (DECTCEM), again.
		assertFalse(mTerminal.isCursorEnabled());
		mTerminal.reset();
		assertTrue("Resetting the terminal should enable the cursor", mTerminal.isCursorEnabled());

		enterString("\033[?25l");
		assertFalse(mTerminal.isCursorEnabled());
		enterString("\033c"); // RIS resetting should enabled cursor.
		assertTrue(mTerminal.isCursorEnabled());
	}

	/** DECSET 2004, controls bracketed paste mode. */
	public void testBracketedPasteMode() {
		withTerminalSized(3, 3);

		mTerminal.paste("a");
		assertEquals("Pasting 'a' should output 'a' when bracketed paste mode is disabled", "a", mOutput.getOutputAndClear());

		enterString("\033[?2004h"); // Enable bracketed paste mode.
		mTerminal.paste("a");
		assertEquals("Pasting when in bracketed paste mode should be bracketed", "\033[200~a\033[201~", mOutput.getOutputAndClear());

		enterString("\033[?2004l"); // Disable bracketed paste mode.
		mTerminal.paste("a");
		assertEquals("Pasting 'a' should output 'a' when bracketed paste mode is disabled", "a", mOutput.getOutputAndClear());

		enterString("\033[?2004h"); // Enable bracketed paste mode, again.
		mTerminal.paste("a");
		assertEquals("Pasting when in bracketed paste mode again should be bracketed", "\033[200~a\033[201~", mOutput.getOutputAndClear());

		mTerminal.paste("\033ab\033cd\033");
		assertEquals("Pasting an escape character should not input it", "\033[200~abcd\033[201~", mOutput.getOutputAndClear());
		mTerminal.paste("\u0081ab\u0081cd\u009F");
		assertEquals("Pasting C1 control codes should not input it", "\033[200~abcd\033[201~", mOutput.getOutputAndClear());

		mTerminal.reset();
		mTerminal.paste("a");
		assertEquals("Terminal reset() should disable bracketed paste mode", "a", mOutput.getOutputAndClear());
	}

	/** DECSET 7, DECAWM, controls wraparound mode. */
	public void testWrapAroundMode() {
		// Default with wraparound:
		withTerminalSized(3, 3).enterString("abcd").assertLinesAre("abc", "d  ", "   ");
		// With wraparound disabled:
		withTerminalSized(3, 3).enterString("\033[?7labcd").assertLinesAre("abd", "   ", "   ");
		enterString("efg").assertLinesAre("abg", "   ", "   ");
		// Re-enabling wraparound:
		enterString("\033[?7hhij").assertLinesAre("abh", "ij ", "   ");
	}

	/** DECSET 1004, focus reporting, used by Textual, prompt_toolkit, vim and tmux. */
	public void testFocusEvents() {
		withTerminalSized(3, 3);
		mTerminal.sendFocusEvent(true);
		assertEquals("No focus events should be sent by default", "", mOutput.getOutputAndClear());
		enterString("\033[?1004h");
		mTerminal.sendFocusEvent(true);
		assertEquals("\033[I", mOutput.getOutputAndClear());
		mTerminal.sendFocusEvent(false);
		assertEquals("\033[O", mOutput.getOutputAndClear());
		enterString("\033[?1004l");
		mTerminal.sendFocusEvent(false);
		assertEquals("", mOutput.getOutputAndClear());
	}

	/** DECSET 2026, synchronized output, used by Textual, Rich and neovim to avoid flicker. */
	public void testSynchronizedOutput() {
		withTerminalSized(3, 3);
		assertFalse(mTerminal.isSynchronizedOutputActive());
		assertEnteringStringGivesResponse("\033[?2026$p", "\033[?2026;2$y");
		enterString("\033[?2026h");
		assertTrue(mTerminal.isSynchronizedOutputActive());
		assertEnteringStringGivesResponse("\033[?2026$p", "\033[?2026;1$y");
		enterString("\033[?2026l");
		assertFalse(mTerminal.isSynchronizedOutputActive());
		enterString("\033[?2026h");
		mTerminal.endSynchronizedOutput();
		assertFalse(mTerminal.isSynchronizedOutputActive());
		enterString("\033[?2026h");
		mTerminal.reset();
		assertFalse("Terminal reset() should end synchronized output", mTerminal.isSynchronizedOutputActive());
	}

	/** DECSET 1003, any-event mouse tracking, which is what Textual and urwid request. */
	public void testAnyEventMouseTracking() {
		withTerminalSized(3, 3);
		assertFalse(mTerminal.isMouseTrackingActive());
		enterString("\033[?1003h\033[?1006h");
		assertTrue(mTerminal.isMouseTrackingActive());
		mTerminal.sendMouseEvent(TerminalEmulator.MOUSE_LEFT_BUTTON_MOVED, 2, 3, true);
		assertEquals("Motion should be reported with 1003", "\033[<32;2;3M", mOutput.getOutputAndClear());
		enterString("\033[?1000h");
		mTerminal.sendMouseEvent(TerminalEmulator.MOUSE_LEFT_BUTTON_MOVED, 2, 3, true);
		assertEquals("Motion should not be reported with only 1000", "", mOutput.getOutputAndClear());
		enterString("\033[?1000l");
		assertFalse(mTerminal.isMouseTrackingActive());
	}

}
