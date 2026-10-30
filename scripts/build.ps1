# Timed debug build for `just build`: runs cargo with --timings (HTML report in
# $CARGO_TARGET_DIR/cargo-timings/) and appends one row to docs/build-times.csv.
$log = Join-Path $PSScriptRoot '..\docs\build-times.csv'

if (-not (Get-Command sccache -ErrorAction SilentlyContinue)) {
    Write-Error 'sccache not found. Install it: winget install Mozilla.sccache'
    exit 1
}
# Stats are server-wide: builds running at once in other worktrees share these counts.
sccache --zero-stats | Out-Null

$sw = [Diagnostics.Stopwatch]::StartNew()
# cmd merges stderr at the OS level, so cargo's progress streams as plain text.
cmd /c "cargo build -p dbt-sa-cli --timings --color always 2>&1" | Tee-Object -Variable lines
$code = $LASTEXITCODE
$sw.Stop()
if ($code -ne 0) { exit $code }

# crates_rebuilt counts every `Compiling` line, sccache hits included; the cache
# columns tell a cold build from a cached one.
$rebuilt = @($lines | Where-Object { $_ -match 'Compiling ' }).Count
$stats = (sccache --show-stats --stats-format json | ConvertFrom-Json).stats
$hits = ($stats.cache_hits.counts.PSObject.Properties.Value | Measure-Object -Sum).Sum
$misses = ($stats.cache_misses.counts.PSObject.Properties.Value | Measure-Object -Sum).Sum

if (-not (Test-Path $log)) {
    Set-Content $log 'timestamp,branch,sha,host,seconds,crates_rebuilt,cache_hits,cache_misses' -Encoding ascii
}
$row = '{0},{1},{2},{3},{4},{5},{6},{7}' -f (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'),
    (git branch --show-current), (git rev-parse --short HEAD), $env:COMPUTERNAME,
    [math]::Round($sw.Elapsed.TotalSeconds), $rebuilt, [int]$hits, [int]$misses
Add-Content $log $row -Encoding ascii
