package com.safety.accountability

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class DigestTest {
    private val min = 60_000L

    @Test fun quietWindowIsOneCleanLine() {
        assertEquals("✅ Clean · 00:00–07:30",
            Digest.build("00:00–07:30", emptyList(), emptyList(), false, emptyList()))
    }

    @Test fun pornAttemptsLeadTheVerdictAndAreCountedPerSite() {
        val out = Digest.build("07:30–00:00", emptyList(), emptyList(), false,
            listOf("pornhub.com", "pornhub.com", "xvideos.com", "google.com"))
        assertTrue(out.lines().first().startsWith("⚠️ 3 adult-site attempt(s)"))
        assertTrue(out.contains("Adult sites: pornhub.com ×2, xvideos.com ×1"))
        assertTrue(out.contains("Other domains: 1"))       // other domains are a count, never a list
        assertFalse(out.contains("google.com"))
    }

    @Test fun telegramVisitsCollapseToOneLinePerChat() {
        val day = 1_755_216_000_000L - ReportSchedule.EAT_OFFSET_MS
        val out = Digest.build("07:30–00:00", emptyList(),
            listOf((day + 16 * 60 * min) to "News", (day + 22 * 60 * min) to "News", (day + 18 * 60 * min) to "Pal"),
            false, emptyList())
        assertTrue(out.contains("• News · 2x · 16:00–22:00"))
        assertTrue(out.contains("• Pal · 1x · 18:00–18:00"))
    }

    @Test fun appsAreTopFiveAndDropUnderAMinute() {
        val apps = listOf("A" to 90 * min, "B" to 30 * min, "C" to 20 * min, "D" to 10 * min,
            "E" to 5 * min, "F" to 2 * min, "Blip" to 20_000L)
        val out = Digest.build("00:00–07:30", apps, emptyList(), false, emptyList())
        assertTrue(out.lines().first().endsWith("2h 37m screen time"))   // blip excluded from the total
        assertTrue(out.contains("Apps: A 1h 30m · B 30m · C 20m · D 10m · E 5m"))
        assertFalse(out.contains("F 2m"))
        assertFalse(out.contains("Blip"))
    }

    @Test fun revokedWatchIsFlagged() {
        val out = Digest.build("00:00–07:30", emptyList(), emptyList(), true, emptyList())
        assertTrue(out.startsWith("⚠️ Telegram watch off"))
    }
}
