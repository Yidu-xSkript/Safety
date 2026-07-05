# Built-in curated list of high-traffic porn domains. Kept intentionally small: the hosts file is a
# VPN-PROOF BACKSTOP for the sites people actually visit — NextDNS handles the comprehensive,
# long-tail block on the normal connection. A giant "all known porn" hosts file (100k+ entries)
# badly slows Windows DNS resolution, so the download path is hard-capped.
# ponytail: curated top-N in hosts + NextDNS for the rest; do not dump 800k entries into hosts.
$script:BuiltInPornDomains = @(
    'pornhub.com','www.pornhub.com','xvideos.com','www.xvideos.com','xnxx.com','www.xnxx.com',
    'xhamster.com','www.xhamster.com','xhamster.desi','redtube.com','www.redtube.com','youporn.com',
    'www.youporn.com','tube8.com','spankbang.com','www.spankbang.com','eporner.com','txxx.com',
    'hclips.com','porntrex.com','beeg.com','www.beeg.com','tnaflix.com','drtuber.com','nuvid.com',
    'sunporno.com','porn.com','www.porn.com','porn300.com','porndig.com','pornhd.com','hqporner.com',
    'motherless.com','fapello.com','thothub.tv','porntn.com','porngo.com','fuq.com','empflix.com',
    'gotporn.com','vporn.com','pornone.com','4tube.com','ashemaletube.com','txxx.tube','upornia.com',
    'hotmovs.com','shooshtime.com','pornhat.com','anyporn.com','ok.xxx','pornhits.com',
    'chaturbate.com','www.chaturbate.com','stripchat.com','bongacams.com','livejasmin.com','cam4.com',
    'camsoda.com','myfreecams.com','flirt4free.com','streamate.com',
    'onlyfans.com','fansly.com','manyvids.com','clips4sale.com',
    'brazzers.com','bangbros.com','realitykings.com','naughtyamerica.com','digitalplayground.com',
    'blacked.com','tushy.com','vixen.com','deeper.com','mofos.com','babes.com','twistys.com',
    'rule34.xxx','e-hentai.org','nhentai.net','hanime.tv','hentaihaven.xxx','fakku.net','hentai2read.com',
    'imagefap.com','sex.com','www.sex.com','literotica.com','adultfriendfinder.com','adult-empire.com',
    'javhd.com','javhub.net','javbus.com','missav.com','jable.tv','sextop1.net',
    'redgifs.com','iwara.tv','pornpics.com','elephanttube.com','porntube.com'
)

function Get-BuiltInPornDomains { return $script:BuiltInPornDomains }

function Get-TorBlockDomains {
    # Static: friction the Tor Browser DOWNLOAD at the hosts level (belt-and-suspenders with the
    # Stop-TorBrowser process kill). Covers the main site + the dist/mirror hosts the installer and
    # in-app updater pull from. NOT exhaustive by design — bridges/mirrors/GitHub releases still
    # exist (friction, not lock); the process kill is the real backstop.
    return @(
        'torproject.org','www.torproject.org','dist.torproject.org','archive.torproject.org',
        'blog.torproject.org','support.torproject.org','gitlab.torproject.org','forum.torproject.org',
        'torproject.net','www.torproject.net','getfoxyproxy.org','tor.eff.org'
    )
}

function Select-PornHits {
    # From "<timestamp> | <url>" browser-history lines, return the lines whose HOST matches a
    # blocked porn domain (exact host or a subdomain of it). Host-suffix match on the parsed
    # hostname, so 'notporn.com' does NOT match 'porn.com'. Pure -> unit-testable. Drives the
    # instant witness alert (a porn URL in history means it was actually loaded, even through a VPN
    # or on a brand-new domain the hosts/NextDNS block missed).
    param([string[]]$Lines = @(), [string[]]$Domains = @())
    if (-not $Domains -or @($Domains).Count -eq 0) { return @() }
    $bare = @{}
    foreach ($d in $Domains) { $x = ($d.Trim().ToLower() -replace '^www\.', ''); if ($x) { $bare[$x] = $true } }
    $hits = @()
    foreach ($line in $Lines) {
        if (-not $line) { continue }
        $url = ((($line -split '\s*\|\s*', 2)[-1]).Trim())
        if (-not $url) { continue }
        $h = $url -replace '^[a-z]+://', ''      # strip scheme
        $h = ($h -split '[/?#]', 2)[0]           # strip path/query/fragment
        $h = ($h -split '@')[-1]                 # strip userinfo
        $h = (($h -split ':')[0]).ToLower() -replace '^www\.', ''   # strip port + leading www
        if (-not $h) { continue }
        # Check the host and each parent suffix against the set (O(labels) per host, ~2-4 lookups),
        # NOT a scan of all 20k+ domains per URL (which would peg the enforcer every poll).
        # e.g. m.xvideos.com -> try "m.xvideos.com" then "xvideos.com" (stops before the bare TLD,
        # so 'notporn.com' never matches on 'com').
        $labels = $h -split '\.'
        for ($i = 0; $i -lt $labels.Count - 1; $i++) {
            if ($bare.ContainsKey(($labels[$i..($labels.Count - 1)] -join '.'))) { $hits += $line; break }
        }
    }
    return $hits
}

function ConvertFrom-NextDnsLog {
    # Parse the NextDNS logs API JSON ({ "data": [ { timestamp, domain, status }, ... ] }) into
    # "<timestamp> | <domain>" lines — the same shape Select-PornHits consumes, so porn-ATTEMPT
    # detection reuses the existing matcher. Pure -> unit-testable with a captured JSON sample.
    param([Parameter(Mandatory)][string]$Json)
    $out = New-Object System.Collections.Generic.List[string]
    $obj = try { $Json | ConvertFrom-Json } catch { $null }
    foreach ($e in @($obj.data)) {
        if ($e.domain) { $out.Add(("{0} | {1}" -f "$($e.timestamp)", $e.domain)) }
    }
    return $out
}

function Get-NextDnsPornAttempts {
    # Fetch recent NextDNS query logs and return the porn-list matches as "<timestamp> | <domain>"
    # lines. NextDNS logs EVERY DNS query, so this catches ATTEMPTS the browser-history reader cannot
    # (a blocked site never loads, so it never appears in history) — the "email me when they TRY,
    # blocked or not" path. Fails quiet (returns @()) on any network/API error so it never breaks the
    # enforcer loop. NextDNS is blind while a VPN tunnels DNS elsewhere; the history alert covers that.
    param(
        [Parameter(Mandatory)][string]$ApiKey,
        [Parameter(Mandatory)][string]$ProfileId,
        [string[]]$Domains = @(),
        [int]$Limit = 100
    )
    try {
        $uri  = "https://api.nextdns.io/profiles/$ProfileId/logs?limit=$Limit"
        $resp = Invoke-WebRequest -Uri $uri -Headers @{ "X-Api-Key" = $ApiKey } -UseBasicParsing -TimeoutSec 20
        return Select-PornHits -Lines (ConvertFrom-NextDnsLog -Json $resp.Content) -Domains $Domains
    } catch { return @() }
}

function ConvertFrom-HostsList {
    # Parse hosts-format ("0.0.0.0 domain" / "127.0.0.1 domain") or plain-domain text
    # into a unique, lower-cased domain list. Skips comments, blank lines, IPs, and localhost.
    param([string]$Text)
    # List.Add (O(1) amortized), NOT $out += (which reallocates the whole array each time = O(n^2)
    # and takes minutes on a 60k-line list). De-dupe via a HashSet so the whole parse is O(n).
    $seen = New-Object System.Collections.Generic.HashSet[string]
    $out  = New-Object System.Collections.Generic.List[string]
    foreach ($line in ($Text -split "`r?`n")) {
        $l = $line.Trim()
        if (-not $l -or $l.StartsWith("#")) { continue }
        $parts = $l -split '\s+'
        $domain = if ($parts.Count -ge 2) { $parts[1] } else { $parts[0] }
        if (-not $domain) { continue }
        $domain = $domain.ToLower()
        if ($domain -eq "localhost" -or $domain -match '^[0-9.]+$') { continue }
        if ($seen.Add($domain)) { $out.Add($domain) }
    }
    return $out
}

function Update-PornBlocklist {
    # Refresh the cached blocklist if missing/older than MaxAgeHours.
    #  - No Url  -> write the built-in curated top list (fast, safe default).
    #  - Url set -> download, parse, and HARD-CAP to MaxDomains so the hosts file stays sane.
    # On any download failure the existing cache is kept (fail-safe: never wipe the block).
    param(
        [string]$Url,
        [Parameter(Mandatory)][string]$CachePath,
        [int]$MaxAgeHours = 24,
        [int]$MaxDomains = 20000,
        [int]$FallbackRetryMinutes = 30
    )
    # A ".fallback" sidecar marks that the cache is only the tiny built-in list (a download failed).
    # While in that state we retry the URL every FallbackRetryMinutes instead of waiting the full
    # MaxAgeHours, so a transient boot-time failure (VPN/DNS still connecting) self-heals in minutes
    # rather than sticking on ~100 domains for a day.
    $fallbackMark = "$CachePath.fallback"
    $onFallback = Test-Path $fallbackMark
    $stale = (-not (Test-Path $CachePath)) -or `
             (((Get-Date) - (Get-Item $CachePath).LastWriteTime).TotalHours -gt $MaxAgeHours)
    if (-not $stale -and $onFallback -and $Url -and `
        (((Get-Date) - (Get-Item $fallbackMark).LastWriteTime).TotalMinutes -gt $FallbackRetryMinutes)) {
        $stale = $true
    }
    if (-not $stale) { return $false }

    if ([string]::IsNullOrWhiteSpace($Url)) {
        Set-Content -Path $CachePath -Value $script:BuiltInPornDomains -Encoding ASCII
        Remove-Item $fallbackMark -ErrorAction SilentlyContinue   # built-in is the chosen list here, not a fallback
        return $true
    }
    try {
        $resp = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 60
        $domains = ConvertFrom-HostsList -Text $resp.Content
        if ($domains.Count -gt $MaxDomains) { $domains = $domains[0..($MaxDomains - 1)] }
        if ($domains.Count -gt 0) {
            Set-Content -Path $CachePath -Value $domains -Encoding ASCII
            Remove-Item $fallbackMark -ErrorAction SilentlyContinue   # got the real list; clear fallback state
            return $true
        }
    } catch { }
    # Download failed. Keep an existing REAL cache untouched. Only seed the built-in when we have
    # nothing yet, or we were already on the fallback (re-stamp the marker so the retry clock resets).
    if (-not (Test-Path $CachePath) -or $onFallback) {
        Set-Content -Path $CachePath -Value $script:BuiltInPornDomains -Encoding ASCII
        Set-Content -Path $fallbackMark -Value (Get-Date -Format o) -Encoding ASCII
        return $true
    }
    return $false
}

function Get-PornBlocklist {
    param([Parameter(Mandatory)][string]$CachePath)
    if (Test-Path $CachePath) { return @(Get-Content -Path $CachePath) }
    return @()
}

function Get-SafeSearchTargets {
    # Pure: force-safe hostname -> the search domains that should redirect to it.
    # YouTube is intentionally EXCLUDED (per user: keep YouTube usable).
    return @{
        'forcesafesearch.google.com' = @('www.google.com', 'google.com')
        'strict.bing.com'            = @('www.bing.com', 'bing.com')
        'safe.duckduckgo.com'        = @('duckduckgo.com', 'www.duckduckgo.com')
    }
}

function Get-SafeSearchRedirects {
    # Resolve each force-safe hostname to its current IP and map the search domains to it.
    # Returns @{ <searchDomain> = <ip> }. Search domains whose force-safe host can't be resolved
    # are simply omitted (fail-open on that one engine rather than breaking search entirely).
    $map = @{}
    $targets = Get-SafeSearchTargets
    foreach ($fs in $targets.Keys) {
        $ip = try {
            (Resolve-DnsName -Name $fs -Type A -ErrorAction Stop |
                Where-Object { $_.IPAddress } | Select-Object -First 1).IPAddress
        } catch { $null }
        if ($ip) { foreach ($d in $targets[$fs]) { $map[$d] = $ip } }
    }
    return $map
}

Export-ModuleMember -Function ConvertFrom-HostsList, Update-PornBlocklist, Get-PornBlocklist, Get-BuiltInPornDomains, Get-TorBlockDomains, Select-PornHits, ConvertFrom-NextDnsLog, Get-NextDnsPornAttempts, Get-SafeSearchTargets, Get-SafeSearchRedirects
