package com.safety.accountability

import org.junit.Assert.assertTrue
import org.junit.Test

class NextDnsReportTest {
    @Test fun groupsByCountMostFrequentFirst() {
        val domains = listOf("google.com", "google.com", "youtube.com", "google.com", "example.com")
        val out = NextDnsReport.format(domains, "hour")
        assertTrue(out.contains("3 distinct domains, 5 queries"))
        assertTrue(out.contains("google.com  x3"))
        assertTrue(out.indexOf("google.com") < out.indexOf("youtube.com"))   // most-frequent first
    }

    @Test fun emptyWindowReadsCleanly() {
        assertTrue(NextDnsReport.format(emptyList(), "hour").contains("No domains"))
    }
}
