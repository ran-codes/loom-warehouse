# Timed debug build for `just build`: runs cargo with --timings (HTML report in
# $CARGO_TARGET_DIR/cargo-timings/) and appends one row to docs/build-times.csv.
$log = Join-Path $PSScriptRoot '..\docs\build-times.csv'

$sw = [Diagnostics.Stopwatch]::StartNew()
# cmd merges stderr at the OS level, so cargo's progress streams as plain text.
cmd /c "cargo build -p dbt-sa-cli --timings --color always 2>&1" | Tee-Object -Variable lines
$code = $LASTEXITCODE
$sw.Stop()
if ($code -ne 0) { exit $code }

# crates_rebuilt separates fresh builds from incremental ones.
$rebuilt = @($lines | Where-Object { $_ -match 'Compiling ' }).Count
if (-not (Test-Path $log)) {
    Set-Content $log 'timestamp,branch,sha,host,seconds,crates_rebuilt' -Encoding ascii
}
$row = '{0},{1},{2},{3},{4},{5}' -f (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'),
    (git branch --show-current), (git rev-parse --short HEAD), $env:COMPUTERNAME,
    [math]::Round($sw.Elapsed.TotalSeconds), $rebuilt
Add-Content $log $row -Encoding ascii
