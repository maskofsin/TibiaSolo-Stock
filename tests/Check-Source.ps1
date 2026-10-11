$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
foreach ($name in @('scripts/Build.ps1','scripts/Prepare.ps1','scripts/Initialize.ps1','scripts/Package-Release.ps1','tests/Check-Source.ps1','tests/Check-Package.ps1','tests/Check-Publish.ps1','tests/Check-Runtime.ps1')) {
    $tokens=$null; $errors=$null
    [Management.Automation.Language.Parser]::ParseFile((Join-Path $root $name),[ref]$tokens,[ref]$errors) | Out-Null
    if ($errors) { throw "PowerShell parsing failed: $name : $($errors.Message -join '; ')" }
}
$lua = Get-Content -LiteralPath (Join-Path $root 'overlays/offline_lifecycle.lua') -Raw
if ($lua -match 'TalkAction|SoloSettings|coins|setVocation|setBaseXpGain') { throw 'Gameplay behavior found in lifecycle overlay.' }
if ($lua -notmatch 'saveServer\(\)' -or $lua -notmatch 'GAME_STATE_SHUTDOWN') { throw 'Graceful save/shutdown missing.' }
$cs = Get-Content -LiteralPath (Join-Path $root 'src/Launcher.cs') -Raw
if ($cs -match 'IPAddress\.Any|solo@localhost|solo-local-db|solo-local-game') { throw 'Unsafe bind or legacy credentials detected.' }
if ($cs -notmatch 'IPAddress\.Loopback' -or $cs -match '\.Kill\(') { throw 'Loopback/safe shutdown contract failed.' }
$init = Get-Content -LiteralPath (Join-Path $root 'scripts/Initialize.ps1') -Raw
if ($init -match "rateExp=|rateLoot=|rateSkill=|rateMagic=|freePremium=|kickIdlePlayerAfterMinutes=|houseLoseAfterInactivity=") { throw 'Gameplay override detected.' }
foreach ($file in @('LICENSE','ACKNOWLEDGEMENTS.md','licenses/CANARY-GPL-2.0.txt','licenses/OTCLIENT-MIT.txt','licenses/MARIADB-COPYING.txt')) {
    if (-not (Test-Path -LiteralPath (Join-Path $root $file))) { throw "License/attribution missing: $file" }
}
Write-Output 'PASS: script syntax, infrastructure-only overlay, loopback, safe shutdown, generated credentials and attribution.'
