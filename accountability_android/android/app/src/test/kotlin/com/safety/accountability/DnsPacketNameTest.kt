package com.safety.accountability

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class DnsPacketNameTest {
    // Build a minimal DNS query: 12-byte header + QNAME labels + 0 terminator + QTYPE/QCLASS.
    private fun query(name: String): ByteArray {
        val out = ArrayList<Byte>()
        repeat(12) { out.add(0) }                         // header (contents irrelevant to name parse)
        for (label in name.split('.')) {
            out.add(label.length.toByte())
            for (c in label) out.add(c.code.toByte())
        }
        out.add(0)                                        // root label
        out.addAll(listOf(0, 1, 0, 1).map { it.toByte() })// QTYPE=A, QCLASS=IN
        return out.toByteArray()
    }

    @Test fun parsesQname() {
        assertEquals("www.pornhub.com", DnsPacket.queryName(query("www.pornhub.com")))
    }

    @Test fun lowercasesAndHandlesShortLabels() {
        assertEquals("xvideos.com", DnsPacket.queryName(query("XVideos.com")))
    }

    @Test fun returnsNullOnTooShort() {
        assertNull(DnsPacket.queryName(ByteArray(5)))
    }
}
