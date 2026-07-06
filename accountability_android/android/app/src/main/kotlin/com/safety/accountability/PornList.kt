package com.safety.accountability

// Curated top porn domains for ATTEMPT detection in the VpnService — the Android twin of the Windows
// sinkhole / NextDNS-attempt alert. NextDNS still does the actual BLOCKING at the DNS layer; this
// list only decides whether a DNS query the tunnel sees is worth emailing the witness about.
// Host-suffix match: "www.pornhub.com" and "m.pornhub.com" both match "pornhub.com", but a lookalike
// like "notporn.com" does NOT match "porn.com".
object PornList {
    // Popular sites only (the ones that matter for accountability); NextDNS covers the long tail at
    // the DNS layer. Extend via a bundled asset list later if broader local matching is ever needed.
    private val domains: Set<String> = setOf(
        "pornhub.com", "xvideos.com", "xnxx.com", "xhamster.com", "redtube.com", "youporn.com",
        "tube8.com", "spankbang.com", "eporner.com", "txxx.com", "beeg.com", "tnaflix.com",
        "drtuber.com", "nuvid.com", "sunporno.com", "porn.com", "porn300.com", "pornhd.com",
        "hqporner.com", "motherless.com", "fapello.com", "porngo.com", "fuq.com", "gotporn.com",
        "vporn.com", "pornone.com", "4tube.com", "upornia.com", "hotmovs.com", "shooshtime.com",
        "pornhat.com", "anyporn.com", "pornhits.com", "chaturbate.com", "stripchat.com",
        "bongacams.com", "livejasmin.com", "cam4.com", "camsoda.com", "myfreecams.com",
        "flirt4free.com", "streamate.com", "onlyfans.com", "fansly.com", "manyvids.com",
        "clips4sale.com", "brazzers.com", "bangbros.com", "realitykings.com", "naughtyamerica.com",
        "blacked.com", "tushy.com", "vixen.com", "deeper.com", "mofos.com", "babes.com",
        "twistys.com", "rule34.xxx", "e-hentai.org", "nhentai.net", "hanime.tv", "hentaihaven.xxx",
        "fakku.net", "imagefap.com", "sex.com", "literotica.com", "javhd.com", "javbus.com",
        "missav.com", "jable.tv", "redgifs.com", "iwara.tv", "pornpics.com", "porntube.com"
    )

    fun isPorn(host: String?): Boolean {
        if (host.isNullOrBlank()) return false
        var h = host.lowercase().trimEnd('.')
        if (h.startsWith("www.")) h = h.substring(4)
        val labels = h.split('.')
        // Check the host and each parent suffix (down to but NOT including the bare TLD).
        for (i in 0 until labels.size - 1) {
            if (domains.contains(labels.subList(i, labels.size).joinToString("."))) return true
        }
        return false
    }
}
