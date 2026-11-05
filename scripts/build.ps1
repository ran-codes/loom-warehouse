# Timed debug build for `just build`: runs cargo with --timings (HTML report in
# $CARGO_TARGET_DIR/cargo-timings/) and writes one JSON record per build to
# docs/build-times/<utc-timestamp>_<sha>.json. One file per build, so branches that
# both log a build never conflict on merge.
$logDir = Join-Path $PSScriptRoot '..\docs\build-times'

# Captured before the build so the record says what tree was compiled. The log
# directory is excluded: earlier uncommitted records must not read as a dirty tree.
$dirty = [bool](git status --porcelain -- . ':!docs/build-times')
# Empty on a detached HEAD; null keeps the JSON field honest instead of a `{}`.
$branch = git branch --show-current
if (-not $branch) { $branch = $null }
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

# crates_rebuilt counts every `Compiling` line. With the shared target dir a warm build
# recompiles only the workspace crates (~20); ~740 means the dependencies were rebuilt too.
$rebuilt = @($lines | Where-Object { ($_ -replace '\x1b\[[0-9;]*m', '') -match '^\s*Compiling ' }).Count

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
}

New-Item -ItemType Directory -Force $logDir | Out-Null
$file = Join-Path $logDir ('{0}_{1}.json' -f $now.ToString('yyyy-MM-ddTHH-mm-ssZ'), $sha)
$json = ($record | ConvertTo-Json) -replace "`r`n", "`n"
[IO.File]::WriteAllText($file, $json + "`n", [Text.UTF8Encoding]::new($false))
Write-Host "Logged $($record.seconds)s, $rebuilt crates -> $(Resolve-Path $file -Relative)"
