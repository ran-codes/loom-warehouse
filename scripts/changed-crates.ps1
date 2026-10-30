# Prints `-p <crate>` for every workspace crate whose files differ from main: commits on this
# branch plus uncommitted and untracked edits. One token per line so a PowerShell caller can splat
# the output straight into cargo. Falls back to dbt-sa-cli (the binary crate) when nothing changed.
$ErrorActionPreference = 'Stop'
$root = (git rev-parse --show-toplevel) -replace '\\', '/'
$base = git merge-base HEAD main
$files = @(git diff --name-only $base) + @(git ls-files --others --exclude-standard)

# Workspace members by directory, deepest first, so a file maps to its nearest crate. Nested
# members (crates/dbt-jinja/minijinja, crates/dbt-sql/*) have no Cargo.toml one level down.
$members = (cargo metadata --no-deps --format-version 1 | ConvertFrom-Json).packages |
    ForEach-Object {
        $dir = (Split-Path $_.manifest_path -Parent) -replace '\\', '/'
        [pscustomobject]@{ Name = $_.name; Dir = $dir.Substring($root.Length + 1) + '/' }
    } | Sort-Object { $_.Dir.Length } -Descending

$names = $files | Where-Object { $_ -like 'crates/*' } | ForEach-Object {
    $file = $_
    $members | Where-Object { $file.StartsWith($_.Dir) } | Select-Object -First 1 -ExpandProperty Name
} | Sort-Object -Unique

if (-not $names) {
    [Console]::Error.WriteLine('changed-crates: no workspace crate differs from main; using dbt-sa-cli')
    $names = @('dbt-sa-cli')
}
foreach ($n in $names) { '-p'; $n }
