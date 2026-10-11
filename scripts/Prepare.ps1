[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$CanarySource,
    [Parameter(Mandatory)][string]$ClientSource,
    [Parameter(Mandatory)][string]$CanaryBinary,
    [Parameter(Mandatory)][string]$ClientBinary,
    [Parameter(Mandatory)][string]$MariaDbDirectory,
    [Parameter(Mandatory)][string]$ThingsDirectory,
    [Parameter(Mandatory)][string]$MapFile,
    [string]$SoundsDirectory,
    [string]$OutputDirectory = (Join-Path $PSScriptRoot '../dist/TibiaSoloStock'),
    [int]$DatabasePort = 18306,
    [int]$GamePort = 18172,
    [int]$LoginPort = 19088,
    [switch]$SkipDatabaseInitialization
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$pins = Get-Content -LiteralPath (Join-Path $repo 'upstream.json') -Raw | ConvertFrom-Json
$output = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $output) { throw 'Output already exists. Choose a new empty location; saves are never overwritten.' }
$inputs = @($CanarySource,$ClientSource,$CanaryBinary,$ClientBinary,$MariaDbDirectory,$ThingsDirectory,$MapFile)
foreach ($path in $inputs) {
    if (-not (Test-Path -LiteralPath $path)) { throw "Required input not found: $path" }
    $absolute = (Resolve-Path -LiteralPath $path).Path
    if ($absolute.StartsWith($output.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase) -or $absolute -eq $output) { throw 'Output cannot contain an input.' }
}
$ports = @($DatabasePort,($GamePort-1),$GamePort,($GamePort+1),$LoginPort)
if (($ports | Select-Object -Unique).Count -ne 5 -or ($ports | Where-Object {$_ -lt 1024 -or $_ -gt 65535})) { throw 'Choose five distinct unprivileged local ports.' }
if ((Get-FileHash -LiteralPath $MapFile -Algorithm SHA256).Hash -ne 'A80DE1DDA6A9ACA3956A9D5B7FB2E0CAEBB451570D26853FC21BEB40D5F31DA2') { throw 'Map does not match the tested stock map. A modified map is not accepted.' }
foreach ($entry in @(@{Path=$CanarySource;Pin=$pins.canary},@{Path=$ClientSource;Pin=$pins.otclient})) {
    & git -C $entry.Path cat-file -e ($entry.Pin.commit+'^{commit}')
    if ($LASTEXITCODE) { throw "Pinned upstream commit is missing: $($entry.Pin.commit)" }
    $origin = (& git -C $entry.Path remote get-url origin).Trim().TrimEnd('/').Replace('.git','')
    if ($origin -ne $entry.Pin.repository) { throw 'Input checkout origin does not match the upstream pin.' }
}
New-Item -ItemType Directory -Path $output | Out-Null
$export = Join-Path $output '.source-export'
New-Item -ItemType Directory -Path $export | Out-Null
function Export-Upstream([string]$checkout,[string]$commit,[string]$name) {
    $zip = Join-Path $export ($name+'.zip')
    & git -C $checkout archive --format=zip "--output=$zip" $commit
    if ($LASTEXITCODE) { throw 'Stock source export failed.' }
    Expand-Archive -LiteralPath $zip -DestinationPath (Join-Path $export $name)
}
Export-Upstream $CanarySource $pins.canary.commit 'canary'
Export-Upstream $ClientSource $pins.otclient.commit 'otclient'
$server = Join-Path $output 'server'
$client = Join-Path $output 'client'
New-Item -ItemType Directory -Path $server,$client | Out-Null
foreach ($folder in @('data','data-canary','data-otservbr-global')) { Copy-Item -LiteralPath (Join-Path $export "canary/$folder") -Destination (Join-Path $server $folder) -Recurse }
foreach ($file in @('key.pem','config.lua.dist')) { Copy-Item -LiteralPath (Join-Path $export "canary/$file") -Destination (Join-Path $server $file) }
Copy-Item -LiteralPath (Join-Path $export 'canary/schema.sql') -Destination (Join-Path $output 'schema.sql')
Copy-Item -LiteralPath $MapFile -Destination (Join-Path $server 'data-otservbr-global/world/otservbr.otbm')
Copy-Item -LiteralPath (Join-Path $repo 'overlays/offline_lifecycle.lua') -Destination (Join-Path $server 'data/scripts/offline_lifecycle.lua')
Copy-Item -LiteralPath $CanaryBinary -Destination (Join-Path $server 'canary.exe')
foreach ($folder in @('data','modules','mods')) { Copy-Item -LiteralPath (Join-Path $export "otclient/$folder") -Destination (Join-Path $client $folder) -Recurse }
Copy-Item -LiteralPath $ClientBinary -Destination (Join-Path $client 'otclient.exe')
foreach ($binary in @($CanaryBinary,$ClientBinary)) {
    $destination = if ($binary -eq $CanaryBinary) {$server} else {$client}
    Get-ChildItem -LiteralPath (Split-Path $binary -Parent) -Filter '*.dll' -File | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $destination $_.Name) }
}
$things = Join-Path $client "data/things/$($pins.protocol)"
if (Test-Path -LiteralPath $things) { throw 'Unexpected bundled modern assets; inspect the upstream export.' }
Copy-Item -LiteralPath $ThingsDirectory -Destination $things -Recurse
if (-not (Test-Path -LiteralPath (Join-Path $things 'catalog-content.json'))) { throw 'ThingsDirectory must contain an extracted compatible catalog-content.json and assets.' }
if ($SoundsDirectory) { Copy-Item -LiteralPath $SoundsDirectory -Destination (Join-Path $client "data/sounds/$($pins.protocol)") -Recurse }
$init = Get-Content -LiteralPath (Join-Path $export 'otclient/init.lua') -Raw
$init = [regex]::Replace($init,'(?s)if ENABLE_SERVERS then.*?\r?\nend',"if ENABLE_SERVERS then`n    Servers_init = { [`"http://127.0.0.1/login`"] = { port = $LoginPort, protocol = $($pins.protocol), httpLogin = true, useAuthenticator = false } }`nend")
# No network updater/asset installer during local play; hash-security settings stay intact.
$init = [regex]::Replace($init,'(?s)(clientAssets\s*=\s*\{\s*enabled\s*=\s*)true','$1false')
$init = $init.Replace('g_app.setName("OTClient - Redemption")','g_app.setName("Tibia Solo Stock")').Replace('g_app.setCompactName("otclient")','g_app.setCompactName("tibiasolostock")')
[IO.File]::WriteAllText((Join-Path $client 'init.lua'),$init,[Text.UTF8Encoding]::new($false))
Copy-Item -LiteralPath $MariaDbDirectory -Destination (Join-Path $output 'database-runtime') -Recurse
Copy-Item -LiteralPath (Join-Path $repo 'scripts/Initialize.ps1') -Destination (Join-Path $output 'Initialize.ps1')
Copy-Item -LiteralPath (Join-Path $repo 'README.md') -Destination (Join-Path $output 'README.md')
Copy-Item -LiteralPath (Join-Path $repo 'ACKNOWLEDGEMENTS.md') -Destination (Join-Path $output 'ACKNOWLEDGEMENTS.md')
Copy-Item -LiteralPath (Join-Path $repo 'LICENSE') -Destination (Join-Path $output 'LICENSE')
Copy-Item -LiteralPath (Join-Path $repo 'licenses') -Destination (Join-Path $output 'licenses') -Recurse
Copy-Item -LiteralPath (Join-Path $repo 'docs') -Destination (Join-Path $output 'docs') -Recurse
& (Join-Path $PSScriptRoot 'Build.ps1') -OutputDirectory $output
if (-not $SkipDatabaseInitialization) { & (Join-Path $output 'Initialize.ps1') -DatabasePort $DatabasePort -GamePort $GamePort -LoginPort $LoginPort }
Write-Output "Clean local package ready: $output"
Write-Warning 'This local package contains your supplied game assets. Do not upload or redistribute it without the relevant permissions. Only the source/launcher-only release is intended for GitHub.'
