[CmdletBinding()]
param([int]$DatabasePort=18306,[int]$GamePort=18172,[int]$LoginPort=19088)
$ErrorActionPreference = 'Stop'
$base = $PSScriptRoot
$bin = Join-Path $base 'database-runtime/bin'
$server = Join-Path $base 'server'
if (Test-Path -LiteralPath (Join-Path $base 'saves/initialized')) { Write-Output 'Already initialized; existing account and saves were not changed.'; return }
if (Test-Path -LiteralPath (Join-Path $base 'saves/database')) { throw 'A database already exists. Refusing to reinitialize or overwrite it.' }
foreach ($port in @($DatabasePort,($GamePort-1),$GamePort,($GamePort+1),$LoginPort)) {
    if (Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction SilentlyContinue) { throw "Local port $port is in use. Existing processes were not changed." }
}
New-Item -ItemType Directory -Path (Join-Path $base 'saves'),(Join-Path $base 'logs'),(Join-Path $base 'backups') -Force | Out-Null
function New-Secret {
    $bytes = New-Object byte[] 16
    $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
    try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }
    return ([BitConverter]::ToString($bytes)).Replace('-','').ToLowerInvariant()
}
$rootPassword = New-Secret
$gamePassword = New-Secret
$playerPassword = (New-Secret).Substring(0,20)
$settings = @{Email='offline@localhost';Password=$playerPassword;DatabasePort=$DatabasePort;GamePort=$GamePort;LoginPort=$LoginPort}
[IO.File]::WriteAllText((Join-Path $base 'settings.json'),($settings | ConvertTo-Json),[Text.UTF8Encoding]::new($false))
$cnf = Join-Path $base 'db-client.cnf'
[IO.File]::WriteAllText($cnf,"[client]`npassword=$rootPassword`n",[Text.UTF8Encoding]::new($false))
& (Join-Path $bin 'mariadb-install-db.exe') "--datadir=$base/saves/database" "--password=$rootPassword" "--port=$DatabasePort" --silent
if ($LASTEXITCODE) { throw 'Local database initialization failed; partial files were retained for diagnosis.' }
$db = Start-Process -FilePath (Join-Path $bin 'mariadbd.exe') -ArgumentList @('--no-defaults',"--basedir=`"$base/database-runtime`"","--datadir=`"$base/saves/database`"",'--bind-address=127.0.0.1',"--port=$DatabasePort",'--innodb-buffer-pool-size=128M','--max-connections=16',"--log-error=`"$base/logs/database.log`"") -WindowStyle Hidden -PassThru
function Sql([string]$query,[string]$database='') {
    $arguments = @("--defaults-extra-file=$cnf",'--host=127.0.0.1',"--port=$DatabasePort",'--user=root','--batch','--skip-column-names')
    if ($database) { $arguments += $database }
    $result = $query | & (Join-Path $bin 'mariadb.exe') @arguments
    if ($LASTEXITCODE) { throw 'Database setup query failed; original files were retained.' }
    return $result
}
try {
    $until = [DateTime]::UtcNow.AddSeconds(60)
    while (-not (Get-NetTCPConnection -State Listen -LocalPort $DatabasePort -ErrorAction SilentlyContinue)) {
        if ($db.HasExited -or [DateTime]::UtcNow -gt $until) { throw 'Database startup failed; see logs/database.log.' }
        Start-Sleep -Milliseconds 300
    }
    Sql "CREATE DATABASE tibiasolostock CHARACTER SET utf8; CREATE USER 'offline'@'127.0.0.1' IDENTIFIED BY '$gamePassword'; GRANT ALL PRIVILEGES ON tibiasolostock.* TO 'offline'@'127.0.0.1';"
    Sql (Get-Content -LiteralPath (Join-Path $base 'schema.sql') -Raw) 'tibiasolostock'
    # Only this newly created database is touched. No imported sample GM accounts.
    Sql "DELETE FROM players; DELETE FROM accounts; INSERT INTO accounts(id,name,email,password,type,premdays,creation) VALUES(100,'offline','offline@localhost',SHA1('$playerPassword'),1,0,UNIX_TIMESTAMP()); INSERT INTO players(name,group_id,account_id,conditions,cap,sex,looktype,lookhead,lookbody,looklegs,lookfeet) VALUES('Adventurer',1,100,'',400,1,128,78,106,116,95);" 'tibiasolostock'
    $config = Get-Content -LiteralPath (Join-Path $server 'config.lua.dist') -Raw
    # Infrastructure only. Every gameplay/rate/premium/idle/house setting is upstream.
    $values = [ordered]@{ip='"127.0.0.1"';bindOnlyGlobalAddress='true';loginProtocolPort=($GamePort-1);gameProtocolPort=$GamePort;statusProtocolPort=($GamePort+1);mysqlHost='"127.0.0.1"';mysqlPort=$DatabasePort;mysqlUser='"offline"';mysqlPass=('"'+$gamePassword+'"');mysqlDatabase='"tibiasolostock"';toggleDownloadMap='false';globalServerSaveShutdown='false';globalServerSaveNotifyMessage='false';generateLuaApiDocs='false';startupDatabaseOptimization='false'}
    foreach ($name in $values.Keys) {
        if (-not [regex]::IsMatch($config,"(?m)^$name\s*=")) { throw "Pinned config key missing: $name" }
        $config = [regex]::Replace($config,"(?m)^$name\s*=.*$","$name = $($values[$name])")
    }
    [IO.File]::WriteAllText((Join-Path $server 'config.lua'),$config,[Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText((Join-Path $base 'saves/initialized'),'Fresh stock world initialized.',[Text.UTF8Encoding]::new($false))
} finally {
    if (-not $db.HasExited) {
        & (Join-Path $bin 'mariadb-admin.exe') "--defaults-extra-file=$cnf" --host=127.0.0.1 "--port=$DatabasePort" --user=root shutdown
        if ($LASTEXITCODE -or -not $db.WaitForExit(30000)) { throw 'Database did not confirm shutdown. Do not move the local package until it stops.' }
    }
}
Write-Output 'Created a fresh ordinary level-1 character. Stock gameplay, no premium grants, store coins or GM powers.'
