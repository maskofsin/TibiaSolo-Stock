[CmdletBinding()]
param([Parameter(Mandatory)][string]$PackageDirectory)
$ErrorActionPreference = 'Stop'
$base = (Resolve-Path -LiteralPath $PackageDirectory).Path
$settings = Get-Content -LiteralPath (Join-Path $base 'settings.json') -Raw | ConvertFrom-Json
$url = "http://127.0.0.1:$($settings.LoginPort)"
$health = Invoke-RestMethod "$url/health"
if (-not $health.ready) { throw 'Local launcher is not ready.' }
$wrong = @{email=$settings.Email;password='deliberately-invalid'} | ConvertTo-Json
$rejected = Invoke-RestMethod "$url/login" -Method Post -ContentType 'application/json' -Body $wrong
if ($rejected.errorCode -ne 3) { throw 'Incorrect password was not rejected.' }
$body = @{email=$settings.Email;password=$settings.Password} | ConvertTo-Json
$response = Invoke-RestMethod "$url/login" -Method Post -ContentType 'application/json' -Body $body
if ($response.playdata.characters.Count -ne 1 -or $response.playdata.characters[0].name -ne 'Adventurer' -or $response.playdata.characters[0].level -ne 1 -or $response.session.ispremium) { throw 'Fresh stock character or premium state mismatch.' }
if ($response.playdata.worlds[0].externaladdress -ne '127.0.0.1' -or $response.playdata.worlds[0].externalport -ne $settings.GamePort) { throw 'Login response does not point to the loopback world.' }
$ports = @($settings.DatabasePort,($settings.GamePort-1),$settings.GamePort,($settings.GamePort+1),$settings.LoginPort)
$listeners = Get-NetTCPConnection -State Listen -LocalPort $ports
if ($listeners.Count -ne 5 -or ($listeners | Where-Object {$_.LocalAddress -ne '127.0.0.1'})) { throw 'A component is missing or is not loopback-only.' }
$row = "SELECT CONCAT(a.type,':',a.premdays,':',a.coins,':',p.group_id,':',p.level,':',p.vocation,':',p.town_id) FROM accounts a JOIN players p ON p.account_id=a.id WHERE a.id=100;" | & (Join-Path $base 'database-runtime/bin/mariadb.exe') "--defaults-extra-file=$base/db-client.cnf" --host=127.0.0.1 "--port=$($settings.DatabasePort)" --user=root --batch --skip-column-names tibiasolostock
if ($LASTEXITCODE -or $row -ne '1:0:0:1:1:0:1') { throw 'Fresh stock account/player database state mismatch.' }
Write-Output 'PASS: ready endpoint, wrong-password rejection, fresh level-1 character, no premium/coins/GM privileges, Dawnport default town and five loopback-only listeners.'
