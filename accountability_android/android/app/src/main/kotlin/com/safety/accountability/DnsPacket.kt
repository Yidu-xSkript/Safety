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
        out[ihl + 6] = 0; out[ihl + 7] = 0
        out[10] = 0; out[11] = 0
        return out
    }
}
