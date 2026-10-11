[CmdletBinding()]
param([Parameter(Mandatory)][string]$PackageDirectory)
$ErrorActionPreference = 'Stop'
$package = (Resolve-Path -LiteralPath $PackageDirectory).Path
$stock = Join-Path $package '.source-export/canary'
$checked = 0
foreach ($folder in @('data','data-canary','data-otservbr-global')) {
    $source = Join-Path $stock $folder
    Get-ChildItem -LiteralPath $source -File -Recurse | ForEach-Object {
        $relative = $_.FullName.Substring($stock.Length).TrimStart('\')
        $target = Join-Path $package "server/$relative"
        if (-not (Test-Path -LiteralPath $target) -or (Get-FileHash -LiteralPath $_.FullName).Hash -ne (Get-FileHash -LiteralPath $target).Hash) { throw "Stock datapack mismatch: $relative" }
        $script:checked++
    }
}
if (Get-ChildItem -LiteralPath (Join-Path $package 'server') -File -Recurse | Where-Object {$_.Name -match '^aaa_solo_|^solo[-_]'}) { throw 'Personal solo files leaked into the stock package.' }
$reference = @{}
$actual = @{}
Get-Content -LiteralPath (Join-Path $stock 'config.lua.dist') | ForEach-Object { if ($_ -match '^([a-zA-Z]\w*)\s*=\s*(.*)$') {$reference[$matches[1]]=$matches[2]} }
Get-Content -LiteralPath (Join-Path $package 'server/config.lua') | ForEach-Object { if ($_ -match '^([a-zA-Z]\w*)\s*=\s*(.*)$') {$actual[$matches[1]]=$matches[2]} }
$allowed = @('ip','bindOnlyGlobalAddress','loginProtocolPort','gameProtocolPort','statusProtocolPort','mysqlHost','mysqlPort','mysqlUser','mysqlPass','mysqlDatabase','toggleDownloadMap','globalServerSaveShutdown','globalServerSaveNotifyMessage','generateLuaApiDocs','startupDatabaseOptimization')
foreach ($key in $reference.Keys) { if ($allowed -notcontains $key -and $reference[$key] -ne $actual[$key]) { throw "Stock gameplay config mismatch: $key" } }
$client = Get-Content -LiteralPath (Join-Path $package 'client/init.lua') -Raw
if ($client -notmatch 'strictManifestSha256 = true' -or $client -notmatch 'allowRawFallbackHashMismatch = false' -or $client -notmatch 'tibiasolostock') { throw 'Client isolation/hash contract failed.' }
Write-Output "PASS: $checked stock datapack files byte-identical, no personal overlays, unchanged gameplay config and isolated client identity."
