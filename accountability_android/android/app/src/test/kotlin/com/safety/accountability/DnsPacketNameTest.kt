package com.safety.accountability

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
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

    @Test fun extractsPayloadFromIpv6UdpPacket() {
        val payload = byteArrayOf(0xDE.toByte(), 0xAD.toByte(), 0xBE.toByte(), 0xEF.toByte())
        val pkt = ByteArray(48 + payload.size)
        pkt[0] = 0x60          // version 6
        pkt[6] = 17            // next header = UDP
        System.arraycopy(payload, 0, pkt, 48, payload.size)
        assertArrayEquals(payload, DnsPacket.extract(pkt, pkt.size))
    }

    @Test fun rejectsIpv6NonUdp() {
        val pkt = ByteArray(48); pkt[0] = 0x60; pkt[6] = 6   // TCP, not UDP
        assertNull(DnsPacket.extract(pkt, pkt.size))
    }

    @Test fun buildsWellFormedIpv6Response() {
        val req = ByteArray(48); req[0] = 0x60; req[6] = 17
        req[8] = 0x11; req[24] = 0x22          // src / dst first byte (to verify the swap)
        req[40] = 0x30; req[42] = 0x40         // src / dst port hi byte
        val answer = byteArrayOf(1, 2, 3, 4)
        val out = DnsPacket.wrapResponse(req, req.size, answer)!!
        assertEquals(48 + answer.size, out.size)
        assertEquals(6, (out[0].toInt() and 0xF0) shr 4)               // still IPv6
        assertEquals(0x22, out[8].toInt() and 0xFF)                    // src/dst swapped
        assertEquals(0x11, out[24].toInt() and 0xFF)
        assertEquals(0x40, out[40].toInt() and 0xFF)                   // ports swapped
        assertEquals(0x30, out[42].toInt() and 0xFF)
        assertEquals(1, out[48].toInt())                              // answer placed
        assertTrue(((out[46].toInt() and 0xFF) or (out[47].toInt() and 0xFF)) != 0)  // UDP checksum set
    }
}
