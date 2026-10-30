# Timed debug build for `just build`: runs cargo with --timings (HTML report in
# $CARGO_TARGET_DIR/cargo-timings/) and writes one JSON record per build to
# docs/build-times/<utc-timestamp>_<sha>.json. One file per build, so branches that
# both log a build never conflict on merge.
$logDir = Join-Path $PSScriptRoot '..\docs\build-times'

if (-not (Get-Command sccache -ErrorAction SilentlyContinue)) {
    Write-Error 'sccache not found. Install it: winget install Mozilla.sccache'
    exit 1
}

# sccache stats are server-wide; snapshot before and after and log the difference.
# Builds running at once in other worktrees still leak into these counts.
function Get-SccacheCounts {
    $json = sccache --show-stats --stats-format json 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $json) { return $null }
    $stats = ($json | ConvertFrom-Json).stats
    $sum = { param($o) if ($null -eq $o) { 0 } else { [int](($o.PSObject.Properties.Value | Measure-Object -Sum).Sum) } }
    [pscustomobject]@{
        hits          = & $sum $stats.cache_hits.counts
        misses        = & $sum $stats.cache_misses.counts
        non_cacheable = & $sum $stats.not_cached
    }
}
$before = Get-SccacheCounts

# Captured before the build so the record says what tree was compiled. The log
# directory is excluded: earlier uncommitted records must not read as a dirty tree.
$dirty = [bool](git status --porcelain -- . ':!docs/build-times')
$branch = git branch --show-current
$sha = git rev-parse --short HEAD
$worktree = Split-Path -Leaf (git rev-parse --show-toplevel)

$sw = [Diagnostics.Stopwatch]::StartNew()
# cmd merges stderr at the OS level, so cargo's progress streams as plain text.
# The filter hides the two upstream Cargo.toml warnings described in the justfile (#28).
$hide = $false
cmd /c "cargo build -p dbt-sa-cli --timings --color always 2>&1" | ForEach-Object {
    $line = "$_"; $plain = $line -replace '\x1b\[[0-9;]*m', ''
    if ($plain -match '^warning: patch `arrow-flight ') { $hide = $true; return }
    if ($plain -match '^warning: profile package spec `sdf-frontend`') { return }
    if ($hide -and $plain -match '^(help: |      \S)') { return }
    $hide = $false; $line
} | Tee-Object -Variable lines
$code = $LASTEXITCODE
$sw.Stop()
if ($code -ne 0) { exit $code }

# crates_rebuilt counts every `Compiling` line, sccache hits included. The sccache
# fields split that into hits, misses, and non-cacheable (incremental workspace crates).
$rebuilt = @($lines | Where-Object { ($_ -replace '\x1b\[[0-9;]*m', '') -match '^\s*Compiling ' }).Count
$after = Get-SccacheCounts
$delta = @{}
foreach ($k in 'hits', 'misses', 'non_cacheable') {
    $delta[$k] = if ($before -and $after) { [math]::Max(0, $after.$k - $before.$k) } else { $null }
}

$now = (Get-Date).ToUniversalTime()
$record = [ordered]@{
    timestamp      = $now.ToString('yyyy-MM-ddTHH:mm:ssZ')
    branch         = $branch
    sha            = $sha
    worktree       = $worktree
    dirty          = $dirty
    host           = $env:COMPUTERNAME
    seconds        = [math]::Round($sw.Elapsed.TotalSeconds)
    crates_rebuilt = $rebuilt
    cache_hits     = $delta.hits
    cache_misses   = $delta.misses
    non_cacheable  = $delta.non_cacheable
}

New-Item -ItemType Directory -Force $logDir | Out-Null
$file = Join-Path $logDir ('{0}_{1}.json' -f $now.ToString('yyyy-MM-ddTHH-mm-ssZ'), $sha)
$json = ($record | ConvertTo-Json) -replace "`r`n", "`n"
[IO.File]::WriteAllText($file, $json + "`n", [Text.UTF8Encoding]::new($false))
Write-Host "Logged $($record.seconds)s, $rebuilt crates -> $(Resolve-Path $file -Relative)"
