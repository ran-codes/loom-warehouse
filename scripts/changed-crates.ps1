# Prints `-p <crate>` for every crate under crates/ whose files differ from main: commits on this
# branch plus uncommitted and untracked edits. One token per line so a PowerShell caller can splat
# the output straight into cargo. Falls back to dbt-sa-cli (the binary crate) when nothing changed.
$ErrorActionPreference = 'Stop'
$root = git rev-parse --show-toplevel
$base = git merge-base HEAD main
$files = @(git diff --name-only $base) + @(git ls-files --others --exclude-standard)
$dirs = $files | Where-Object { $_ -like 'crates/*/*' } | ForEach-Object { ($_ -split '/')[1] } | Sort-Object -Unique
$names = foreach ($d in $dirs) {
    $toml = Join-Path $root "crates/$d/Cargo.toml"
    if (Test-Path $toml) {
        $m = Select-String -Path $toml -Pattern '^name\s*=\s*"([^"]+)"' | Select-Object -First 1
        if ($m) { $m.Matches[0].Groups[1].Value }
    }
}
if (-not $names) {
    [Console]::Error.WriteLine('changed-crates: nothing differs from main under crates/; using dbt-sa-cli')
    $names = @('dbt-sa-cli')
}
foreach ($n in $names) { '-p'; $n }
