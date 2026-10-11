[CmdletBinding()]
param([string]$OutputDirectory=(Join-Path $PSScriptRoot '../artifacts'))
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$release = Join-Path $OutputDirectory 'TibiaSoloStock-launcher-source'
if (Test-Path -LiteralPath $release) { throw 'Release output already exists; choose another output directory.' }
New-Item -ItemType Directory -Path $release -Force | Out-Null
& (Join-Path $PSScriptRoot 'Build.ps1') -OutputDirectory $release
# Explicit public allowlist: never recursively package the installed game or dist.
foreach ($name in @('README.md','ACKNOWLEDGEMENTS.md','LICENSE','upstream.json','src','scripts','overlays','tests','docs','licenses')) {
    Copy-Item -LiteralPath (Join-Path $repo $name) -Destination (Join-Path $release $name) -Recurse
}
$zip = Join-Path $OutputDirectory 'TibiaSoloStock-v0.1.0-launcher-source.zip'
if (Test-Path -LiteralPath $zip) { throw 'Release archive already exists; refusing to overwrite.' }
Compress-Archive -LiteralPath $release -DestinationPath $zip
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead([IO.Path]::GetFullPath($zip))
try {
    foreach ($entry in $archive.Entries) {
        if ($entry.FullName -match '(?i)(settings\.json|db-client\.cnf|\.otbm$|\.dat$|\.spr$|\.sql$|\.dll$|/saves/|/backups/|/server/|/client/|/database-runtime/)') { throw "Excluded/private artifact entered release: $($entry.FullName)" }
        if ($entry.FullName.EndsWith('.exe',[StringComparison]::OrdinalIgnoreCase) -and -not $entry.FullName.EndsWith('/TibiaSoloStock.exe',[StringComparison]::OrdinalIgnoreCase)) { throw 'Unexpected executable in release.' }
    }
} finally { $archive.Dispose() }
Write-Output "Verified launcher/source-only release: $zip"
Get-FileHash -LiteralPath $zip -Algorithm SHA256 | Select-Object -ExpandProperty Hash
