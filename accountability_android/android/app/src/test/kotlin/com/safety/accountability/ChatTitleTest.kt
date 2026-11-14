package com.safety.accountability
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ChatTitleTest {
    private fun n(text: String, top: Int, left: Int = 0) = ChatTitle.Node(text, top, left)

    @Test fun picksTheTopmostToolbarTextAsTheTitle() {
        // Real shape: title on top, subscriber count underneath.
        val t = ChatTitle.pick(listOf(n("1 234 subscribers", 96), n("Some Channel", 48)))
        assertEquals("Some Channel", t)
    }

    @Test fun breaksTiesLeftToRight() {
        assertEquals("Left", ChatTitle.pick(listOf(n("Right", 48, left = 400), n("Left", 48, left = 80))))
    }

    @Test fun ignoresTheChatListAndSettingsScreens() {
        assertNull(ChatTitle.pick(listOf(n("Telegram", 48))))
        assertNull(ChatTitle.pick(listOf(n("Settings", 48))))
    }

    @Test fun rejectsLongTextThatIsAMessageNotATitle() {
        assertNull(ChatTitle.pick(listOf(n("x".repeat(120), 48))))
    }

    @Test fun emptyScreenYieldsNoTitle() {
        assertNull(ChatTitle.pick(emptyList()))
        assertNull(ChatTitle.pick(listOf(n("   ", 48))))
    }

    @Test fun sameChatDoesNotRelogUntilTheGapPasses() {
        assertFalse(ChatTitle.shouldRecord("A Channel", 1_000L, "A Channel", 1_000L + 60_000L))
        assertTrue(ChatTitle.shouldRecord("A Channel", 1_000L, "A Channel", 1_000L + ChatTitle.REPEAT_MS))
    }

    @Test fun switchingChatsAlwaysLogs() {
        assertTrue(ChatTitle.shouldRecord("A Channel", 1_000L, "B Channel", 1_050L))
        assertTrue(ChatTitle.shouldRecord(null, 0L, "A Channel", 1_000L))
    }

    @Test fun parseKeepsTitlesWithSpacesAndDropsJunk() {
        val got = ChatTitle.parse(listOf("1700000000000\tSome Channel Name", "", "garbage", "\tno ts", "12\t"))
        assertEquals(listOf(1_700_000_000_000L to "Some Channel Name"), got)
    }

    @Test fun withinKeepsOnlyTheReportWindow() {
        val now = 10_000_000L
        val entries = listOf(now - 500L to "recent", now - 9_000_000L to "old", now + 5_000L to "future")
        assertEquals(listOf(now - 500L to "recent"), ChatTitle.within(entries, now, 3_600_000L))
    }
}
