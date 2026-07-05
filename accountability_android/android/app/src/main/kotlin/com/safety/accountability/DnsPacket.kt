package com.safety.accountability
object DnsPacket {
    // Returns the DNS payload from an IPv4/UDP packet, or null if not IPv4/UDP.
    fun extract(pkt: ByteArray, len: Int): ByteArray? {
        if (len < 28) return null
        val ihl = (pkt[0].toInt() and 0x0F) * 4
        val proto = pkt[9].toInt() and 0xFF
        if (proto != 17) return null                 // 17 = UDP
        val payloadStart = ihl + 8
        if (payloadStart > len) return null
        return pkt.copyOfRange(payloadStart, len)
    }
    // Extract the queried domain (QNAME) from a DNS query message (the UDP payload from extract()).
    // Returns a lower-cased domain, or null if it can't be parsed. Queries don't use name
    // compression, so a compression pointer (top two bits set) is treated as unparseable.
    fun queryName(dns: ByteArray): String? {
        try {
            if (dns.size < 13) return null            // 12-byte header + at least the root label
            var i = 12                                // skip the DNS header
            val sb = StringBuilder()
            while (i < dns.size) {
                val len = dns[i].toInt() and 0xFF
                if (len == 0) break
                if (len and 0xC0 != 0) return null    // compression pointer: not expected in a query
                i++
                if (i + len > dns.size) return null
                if (sb.isNotEmpty()) sb.append('.')
                for (j in 0 until len) sb.append((dns[i + j].toInt() and 0xFF).toChar())
                i += len
            }
            return if (sb.isEmpty()) null else sb.toString().lowercase()
        } catch (e: Exception) { return null }
    }

    // Builds a response packet by swapping src/dst and replacing the UDP payload.
    // Zeroes checksums (allowed for UDP over IPv4). Verify on device.
    fun wrapResponse(reqPkt: ByteArray, len: Int, answer: ByteArray): ByteArray? {
        val ihl = (reqPkt[0].toInt() and 0x0F) * 4
        val out = ByteArray(ihl + 8 + answer.size)
        System.arraycopy(reqPkt, 0, out, 0, ihl + 8)
        for (i in 0 until 4) { val t = out[12 + i]; out[12 + i] = out[16 + i]; out[16 + i] = t }
        for (i in 0 until 2) { val t = out[ihl + i]; out[ihl + i] = out[ihl + 2 + i]; out[ihl + 2 + i] = t }
        System.arraycopy(answer, 0, out, ihl + 8, answer.size)
        val totalLen = out.size
        out[2] = (totalLen shr 8).toByte(); out[3] = totalLen.toByte()
        val udpLen = 8 + answer.size
        out[ihl + 4] = (udpLen shr 8).toByte(); out[ihl + 5] = udpLen.toByte()
        out[ihl + 6] = 0; out[ihl + 7] = 0              // UDP checksum 0 = "not computed" (legal on IPv4)
        // IPv4 header checksum is MANDATORY and cannot be left 0 — the kernel drops packets with a bad
        // one, so zeroing it (the old bug) meant every DNS reply was discarded (audit #8). Recompute it.
        out[10] = 0; out[11] = 0
        var sum = 0
        var k = 0
        while (k < ihl) {
            sum += ((out[k].toInt() and 0xFF) shl 8) or (out[k + 1].toInt() and 0xFF)
            k += 2
        }
        while (sum shr 16 != 0) sum = (sum and 0xFFFF) + (sum shr 16)
        val csum = sum.inv() and 0xFFFF
        out[10] = (csum shr 8).toByte(); out[11] = csum.toByte()
        return out
    }
}
