package com.safety.accountability

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class TelegramReporterTest {
    @Test fun shortTextIsOneMessage() {
        assertEquals(listOf("a\nb"), TelegramReporter.chunk("a\nb"))
    }

    @Test fun longReportSplitsOnLineBreaksUnderTheLimit() {
        val text = (1..2000).joinToString("\n") { "line $it" }
        val parts = TelegramReporter.chunk(text)
        assertTrue(parts.size > 1)
        assertTrue(parts.all { it.length <= TelegramReporter.MAX })
        assertEquals(text, parts.joinToString("\n"))   // nothing lost, no row cut in half
    }

    @Test fun oneGiantLineIsHardSplit() {
        val parts = TelegramReporter.chunk("x".repeat(TelegramReporter.MAX * 2 + 5))
        assertTrue(parts.all { it.length <= TelegramReporter.MAX })
        assertEquals(TelegramReporter.MAX * 2 + 5, parts.sumOf { it.length })
    }
}
