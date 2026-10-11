[CmdletBinding()]
param([string]$OutputDirectory = (Join-Path $PSScriptRoot '../dist/launcher'))
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$csc = Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
if (-not (Test-Path -LiteralPath $csc)) { throw '.NET Framework 4.x compiler not found. This build requires Windows.' }
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
& $csc /nologo /target:winexe "/out:$OutputDirectory/TibiaSoloStock.exe" /reference:System.Windows.Forms.dll /reference:System.Drawing.dll /reference:System.Web.Extensions.dll (Join-Path $repo 'src/Launcher.cs')
if ($LASTEXITCODE) { throw 'Launcher compilation failed.' }
Write-Output "Built $OutputDirectory/TibiaSoloStock.exe"
