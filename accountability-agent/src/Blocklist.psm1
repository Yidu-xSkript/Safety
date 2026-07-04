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

function ConvertFrom-HostsList {
    # Parse hosts-format ("0.0.0.0 domain" / "127.0.0.1 domain") or plain-domain text
    # into a unique, lower-cased domain list. Skips comments, blank lines, IPs, and localhost.
    param([string]$Text)
    $out = @()
    foreach ($line in ($Text -split "`r?`n")) {
        $l = $line.Trim()
        if (-not $l -or $l.StartsWith("#")) { continue }
        $parts = $l -split '\s+'
        $domain = if ($parts.Count -ge 2) { $parts[1] } else { $parts[0] }
        if (-not $domain) { continue }
        $domain = $domain.ToLower()
        if ($domain -eq "localhost" -or $domain -match '^[0-9.]+$') { continue }
        $out += $domain
    }
    return ($out | Select-Object -Unique)
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
        [int]$MaxDomains = 20000
    )
    $stale = (-not (Test-Path $CachePath)) -or `
             (((Get-Date) - (Get-Item $CachePath).LastWriteTime).TotalHours -gt $MaxAgeHours)
    if (-not $stale) { return $false }

    if ([string]::IsNullOrWhiteSpace($Url)) {
        Set-Content -Path $CachePath -Value $script:BuiltInPornDomains -Encoding ASCII
        return $true
    }
    try {
        $resp = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 60
        $domains = ConvertFrom-HostsList -Text $resp.Content
        if ($domains.Count -gt $MaxDomains) { $domains = $domains[0..($MaxDomains - 1)] }
        if ($domains.Count -gt 0) {
            Set-Content -Path $CachePath -Value $domains -Encoding ASCII
            return $true
        }
    } catch { }
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

Export-ModuleMember -Function ConvertFrom-HostsList, Update-PornBlocklist, Get-PornBlocklist, Get-BuiltInPornDomains, Get-SafeSearchTargets, Get-SafeSearchRedirects
