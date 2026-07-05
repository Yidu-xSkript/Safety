# Reads Chromium (Chrome/Edge/Brave) browsing history via Windows' built-in SQLite (winsqlite3.dll)
# — no bundled dependency. Captures full URLs incl. search queries (google.com/search?q=...), which
# works regardless of VPN because it reads the browser's own on-disk history. Incognito is NOT
# recorded by the browser, so it is not (and cannot be) captured here.

$script:MiniSqliteSrc = @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public static class MiniSqlite {
    [DllImport("winsqlite3.dll", EntryPoint="sqlite3_open16", CharSet=CharSet.Unicode)]  static extern int Open(string f, out IntPtr db);
    [DllImport("winsqlite3.dll", EntryPoint="sqlite3_prepare16_v2", CharSet=CharSet.Unicode)] static extern int Prepare(IntPtr db, string sql, int n, out IntPtr stmt, IntPtr tail);
    [DllImport("winsqlite3.dll", EntryPoint="sqlite3_step")]         static extern int Step(IntPtr stmt);
    [DllImport("winsqlite3.dll", EntryPoint="sqlite3_column_text16")]static extern IntPtr ColText(IntPtr stmt, int c);
    [DllImport("winsqlite3.dll", EntryPoint="sqlite3_finalize")]     static extern int Final(IntPtr stmt);
    [DllImport("winsqlite3.dll", EntryPoint="sqlite3_close")]        static extern int CloseDb(IntPtr db);
    [DllImport("winsqlite3.dll", EntryPoint="sqlite3_open", CharSet=CharSet.Ansi)] static extern int OpenA(string f, out IntPtr db);
    [DllImport("winsqlite3.dll", EntryPoint="sqlite3_exec", CharSet=CharSet.Ansi)] static extern int Exec(IntPtr db, string sql, IntPtr cb, IntPtr a, IntPtr e);

    public static List<string[]> Query(string dbPath, string sql, int cols) {
        var rows = new List<string[]>(); IntPtr db;
        if (Open(dbPath, out db) != 0) { if (db != IntPtr.Zero) CloseDb(db); return rows; }
        try {
            IntPtr stmt;
            if (Prepare(db, sql, -1, out stmt, IntPtr.Zero) != 0) return rows;
            while (Step(stmt) == 100) {   // SQLITE_ROW
                var row = new string[cols];
                for (int i = 0; i < cols; i++) { var p = ColText(stmt, i); row[i] = p == IntPtr.Zero ? "" : Marshal.PtrToStringUni(p); }
                rows.Add(row);
            }
            Final(stmt);
        } finally { CloseDb(db); }
        return rows;
    }
    // Only used by the self-test to build a fixture DB.
    public static int ExecSql(string dbPath, string sql) {
        IntPtr db; if (OpenA(dbPath, out db) != 0) { if (db != IntPtr.Zero) CloseDb(db); return -1; }
        int rc = Exec(db, sql, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero); CloseDb(db); return rc;
    }
}
'@
if (-not ([System.Management.Automation.PSTypeName]'MiniSqlite').Type) {
    Add-Type -TypeDefinition $script:MiniSqliteSrc -ErrorAction SilentlyContinue
}

function Get-ChromiumHistory {
    # Read one Chromium History DB, returning rows visited after $SinceChromeTime.
    # last_visit_time is microseconds since 1601-01-01 (WebKit epoch). The file is locked while the
    # browser is open, so we copy it first.
    param([Parameter(Mandatory)][string]$HistoryPath, [long]$SinceChromeTime = 0)
    if (-not (Test-Path $HistoryPath)) { return @() }
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("aa-hist-" + [guid]::NewGuid().ToString("N").Substring(0,8) + ".db")
    try { Copy-Item -Path $HistoryPath -Destination $tmp -Force -ErrorAction Stop } catch { return @() }
    try {
        $sql = "SELECT url, title, last_visit_time FROM urls WHERE last_visit_time > $SinceChromeTime ORDER BY last_visit_time ASC LIMIT 1000"
        $out = @()
        foreach ($r in [MiniSqlite]::Query($tmp, $sql, 3)) {
            $out += [pscustomobject]@{ Url = $r[0]; Title = $r[1]; ChromeTime = [long]$r[2] }
        }
        return $out
    } finally { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
}

function Get-BrowserHistory {
    # Aggregate recent history from installed Chromium browsers, newer than the watermark.
    # Returns @{ Entries = <"timestamp | url" strings>; MaxChromeTime = <long watermark> } so the
    # caller persists the watermark and only reports new visits.
    param([long]$SinceChromeTime = 0)
    $local = $env:LOCALAPPDATA
    $profiles = @(
        (Join-Path $local "Google\Chrome\User Data\Default\History"),
        (Join-Path $local "Microsoft\Edge\User Data\Default\History"),
        (Join-Path $local "BraveSoftware\Brave-Browser\User Data\Default\History")
    )
    $entries = @(); $maxTime = $SinceChromeTime
    foreach ($p in $profiles) {
        foreach ($e in (Get-ChromiumHistory -HistoryPath $p -SinceChromeTime $SinceChromeTime)) {
            $unixSec = [math]::Floor($e.ChromeTime / 1000000) - 11644473600   # WebKit -> Unix seconds
            $ts = try { ([datetimeoffset]::FromUnixTimeSeconds([long]$unixSec)).LocalDateTime.ToString("s") } catch { "" }
            $entries += ("{0} | {1}" -f $ts, $e.Url)
            if ($e.ChromeTime -gt $maxTime) { $maxTime = $e.ChromeTime }
        }
    }
    return @{ Entries = $entries; MaxChromeTime = $maxTime }
}

Export-ModuleMember -Function Get-BrowserHistory, Get-ChromiumHistory
