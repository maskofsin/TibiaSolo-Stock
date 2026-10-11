$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$tracked = & git -C $root ls-files
if ($LASTEXITCODE -or -not $tracked) { throw 'Run this check from a Git checkout with tracked files.' }
foreach ($name in $tracked) {
    if ($name -notmatch '^(\.github/|\.gitignore$|ACKNOWLEDGEMENTS\.md$|CONTRIBUTING\.md$|LICENSE$|README\.md$|SECURITY\.md$|docs/|licenses/|overlays/|scripts/|src/|tests/|upstream\.json$)') { throw "Unexpected tracked path: $name" }
    if ($name -match '(?i)(\.(exe|dll|pdb|zip|otbm|dat|spr|sql|pem|cnf|log)$|settings\.json|saves/|backups/)') { throw "Private/binary artifact tracked: $name" }
    $text = Get-Content -LiteralPath (Join-Path $root $name) -Raw
    if ($text -match 'C:\\Users\\Joao|100\.72\.212\.38|xify\.kudokei\.com|gh[pousr]_[A-Za-z0-9]{36,}|github_pat_[A-Za-z0-9_]{40,}|-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----') { throw "Potential private information in $name" }
}
Write-Output "PASS: $($tracked.Count) tracked files; explicit public allowlist, no runtime artifacts, private PC/server identifiers or common GitHub secret formats."
