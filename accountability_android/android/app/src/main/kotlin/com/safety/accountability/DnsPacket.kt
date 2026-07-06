package com.safety.accountability
object DnsPacket {
    // Returns the DNS (UDP) payload from an IPv4 OR IPv6 packet, or null if it isn't UDP (or uses
    // IPv6 extension headers). Handling IPv6 closes the DNS-bypass hole on dual-stack / IPv6 networks,
    // where DNS would otherwise resolve over IPv6 entirely outside an IPv4-only tunnel (audit #9).
    fun extract(pkt: ByteArray, len: Int): ByteArray? {
        if (len < 1) return null
        return when ((pkt[0].toInt() and 0xF0) shr 4) {
            4 -> {
                if (len < 28) return null
                val ihl = (pkt[0].toInt() and 0x0F) * 4
                if ((pkt[9].toInt() and 0xFF) != 17) return null   // 17 = UDP
                val start = ihl + 8
                if (start > len) return null
                pkt.copyOfRange(start, len)
            }
            6 -> {
                if (len < 48) return null                          // 40-byte IPv6 header + 8-byte UDP
                if ((pkt[6].toInt() and 0xFF) != 17) return null   // next header = UDP (no ext headers)
                pkt.copyOfRange(48, len)
            }
            else -> null
        }
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

    // Builds a response packet (swap src/dst + ports, replace the UDP payload) for IPv4 or IPv6.
    fun wrapResponse(reqPkt: ByteArray, len: Int, answer: ByteArray): ByteArray? =
        if (reqPkt.isEmpty()) null
        else if ((reqPkt[0].toInt() and 0xF0) shr 4 == 6) wrapIpv6(reqPkt, answer)
        else wrapIpv4(reqPkt, answer)

    private fun wrapIpv4(reqPkt: ByteArray, answer: ByteArray): ByteArray {
        val ihl = (reqPkt[0].toInt() and 0x0F) * 4
        val out = ByteArray(ihl + 8 + answer.size)
        System.arraycopy(reqPkt, 0, out, 0, ihl + 8)
        for (i in 0 until 4) { val t = out[12 + i]; out[12 + i] = out[16 + i]; out[16 + i] = t }
        for (i in 0 until 2) { val t = out[ihl + i]; out[ihl + i] = out[ihl + 2 + i]; out[ihl + 2 + i] = t }
        System.arraycopy(answer, 0, out, ihl + 8, answer.size)
        out[2] = (out.size shr 8).toByte(); out[3] = out.size.toByte()
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

    private fun wrapIpv6(req: ByteArray, answer: ByteArray): ByteArray {
        val udpLen = 8 + answer.size
        val out = ByteArray(40 + udpLen)
        System.arraycopy(req, 0, out, 0, 48)            // IPv6 header (40) + UDP header (8)
        for (i in 0 until 16) { val t = out[8 + i]; out[8 + i] = out[24 + i]; out[24 + i] = t }  // swap src/dst
        for (i in 0 until 2) { val t = out[40 + i]; out[40 + i] = out[42 + i]; out[42 + i] = t }  // swap ports
        System.arraycopy(answer, 0, out, 48, answer.size)
        out[4] = (udpLen shr 8).toByte(); out[5] = udpLen.toByte()     // IPv6 payload length
        out[44] = (udpLen shr 8).toByte(); out[45] = udpLen.toByte()   // UDP length
        out[46] = 0; out[47] = 0                                       // zero the UDP checksum field first
        // IPv6 has no header checksum, but the UDP checksum is MANDATORY (0 is illegal). Compute it over
        // the pseudo-header (src, dst, UDP length, next-header=17) + the UDP header + data.
        var sum = 0L
        var i = 8
        while (i < 40) { sum += (((out[i].toInt() and 0xFF) shl 8) or (out[i + 1].toInt() and 0xFF)).toLong(); i += 2 }
        sum += udpLen.toLong() + 17L
        var j = 40
        val end = 40 + udpLen
        while (j + 1 < end) { sum += (((out[j].toInt() and 0xFF) shl 8) or (out[j + 1].toInt() and 0xFF)).toLong(); j += 2 }
        if (j < end) sum += ((out[j].toInt() and 0xFF) shl 8).toLong()
        while (sum shr 16 != 0L) sum = (sum and 0xFFFF) + (sum shr 16)
        var c = (sum.inv() and 0xFFFF).toInt()
        if (c == 0) c = 0xFFFF                                         // UDP checksum 0 illegal on IPv6
        out[46] = (c shr 8).toByte(); out[47] = c.toByte()
        return out
    }
}
