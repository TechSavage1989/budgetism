# Installs an empty, loopback-only development server from the verified package.
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$InstallDirectory,
    [string]$PackageDirectory = '',
    [ValidateRange(1024,65535)][int]$DatabasePort = 55432,
    [ValidateRange(1024,65535)][int]$ApiPort = 55080
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
function Set-PrivateDirectory([string]$Path, [hashtable]$Accounts) {
    $acl = New-Object Security.AccessControl.DirectorySecurity
    $acl.SetAccessRuleProtection($true,$false)
    foreach ($sid in @('S-1-5-18','S-1-5-32-544',[Security.Principal.WindowsIdentity]::GetCurrent().User.Value)) {
        $identity = [Security.Principal.SecurityIdentifier]::new($sid)
        $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($identity,'FullControl','ContainerInherit,ObjectInherit','None','Allow'))
    }
    foreach ($name in $Accounts.Keys) {
        $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($name,$Accounts[$name],'ContainerInherit,ObjectInherit','None','Allow'))
    }
    Set-Acl -LiteralPath $Path -AclObject $acl
}
function New-Secret {
    $bytes = New-Object byte[] 32
    $random = [Security.Cryptography.RandomNumberGenerator]::Create()
    try { $random.GetBytes($bytes) } finally { $random.Dispose() }
    return ([BitConverter]::ToString($bytes)).Replace('-','').ToLowerInvariant()
}
function Invoke-ServiceCommand([string[]]$Arguments) {
    & "$env:SystemRoot\System32\sc.exe" @Arguments | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Windows service configuration failed.' }
}
function Assert-Health {
    for ($attempt=0; $attempt -lt 30; $attempt++) {
        try {
            $health = Invoke-RestMethod -Uri "http://127.0.0.1:$ApiPort/health" -TimeoutSec 2
            if ($health.status -eq 'ok') { return }
        } catch { }
        Start-Sleep -Seconds 1
    }
    throw 'Budgetism API did not become healthy.'
}

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Open Windows PowerShell as Administrator to install the services.'
}
if ($DatabasePort -eq $ApiPort) { throw 'API and database ports must differ.' }
if ([string]::IsNullOrWhiteSpace($PackageDirectory)) { $PackageDirectory = $PSScriptRoot }
$package = [IO.Path]::GetFullPath($PackageDirectory).TrimEnd('\')
$destination = [IO.Path]::GetFullPath($InstallDirectory).TrimEnd('\')
if ($destination -match '["\r\n]' -or $destination.StartsWith('\\') -or $destination.Length -lt 8) { throw 'Use a local installation folder.' }
if (Test-Path -LiteralPath $destination) { throw 'Installation folder already exists. Existing data will not be overwritten.' }
$parent = Split-Path $destination -Parent
if (-not (Test-Path -LiteralPath $parent -PathType Container)) { throw 'Installation parent folder must already exist.' }
# Reject junctions/symlinks in the destination ancestry before changing any ACL.
$ancestor = Get-Item -LiteralPath $parent
while ($null -ne $ancestor) {
    if (($ancestor.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Installation parent cannot be a junction or symbolic link.' }
    $ancestor = $ancestor.Parent
}
foreach ($name in @('BudgetismApi','BudgetismDatabase')) {
    if (Get-Service -Name $name -ErrorAction SilentlyContinue) { throw 'Budgetism service already exists. Use a reviewed upgrade instead.' }
}
foreach ($port in @($DatabasePort,$ApiPort)) {
    $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,$port)
    try { $listener.Start() } catch { throw "Port $port is occupied." } finally { $listener.Stop() }
}
$manifest = Get-Content -LiteralPath (Join-Path $package 'manifest.json') -Raw | ConvertFrom-Json
if ($manifest.format -ne 1) { throw 'Unsupported manifest.' }
foreach ($required in @('api/Budgetism.Api.exe','postgresql/bin/initdb.exe','postgresql/bin/pg_ctl.exe','postgresql/bin/psql.exe','postgresql/bin/postgres.exe','Install-BudgetismServer.ps1')) {
    if (@($manifest.files | Where-Object path -eq $required).Count -ne 1) { throw 'Missing or duplicate required package entry.' }
}
$seen = @{}
foreach ($entry in $manifest.files) {
    $path = [IO.Path]::GetFullPath((Join-Path $package $entry.path))
    if (-not $path.StartsWith($package+'\',[StringComparison]::OrdinalIgnoreCase) -or $seen.ContainsKey($path)) { throw 'Unsafe or repeated package path.' }
    $seen[$path] = $true
    if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $entry.sha256) { throw 'Package integrity check failed.' }
}
$utf8 = New-Object Text.UTF8Encoding $false
$null = New-Item -ItemType Directory -Path $destination
Set-PrivateDirectory $destination @{}
$admin = Join-Path $destination 'admin'
$secrets = Join-Path $destination 'api-secrets'
$data = Join-Path $destination 'database'
foreach ($path in @($admin,$secrets)) { $null = New-Item -ItemType Directory -Path $path; Set-PrivateDirectory $path @{} }
$createdDatabaseService = $false
$createdApiService = $false
$oldPassFile = [Environment]::GetEnvironmentVariable('PGPASSFILE','Process')
$oldOptions = [Environment]::GetEnvironmentVariable('PGOPTIONS','Process')
try {
    # Copy only manifested runtime files, excluding the package's prior test runs.
    foreach ($entry in $manifest.files) {
        if ($entry.path -notmatch '^(api|postgresql)/') { continue }
        $target = Join-Path $destination $entry.path
        $null = New-Item -ItemType Directory -Path (Split-Path $target -Parent) -Force
        Copy-Item -LiteralPath (Join-Path $package $entry.path) -Destination $target
        if ((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ne $entry.sha256) { throw 'Installed file hash mismatch.' }
    }
    $pgBin = Join-Path $destination 'postgresql\bin'
    $adminPassword = New-Secret
    $appPassword = New-Secret
    $passwordFile = Join-Path $admin 'database-password'
    [IO.File]::WriteAllText($passwordFile,$adminPassword,$utf8)
    [IO.File]::WriteAllText((Join-Path $secrets 'database-password'),$appPassword,$utf8)
    & (Join-Path $pgBin 'initdb.exe') -D $data -U budgetism_admin --auth=scram-sha-256 --encoding=UTF8 --locale=C "--pwfile=$passwordFile" *> (Join-Path $admin 'init.log')
    if ($LASTEXITCODE -ne 0) { throw 'Database initialization failed; see admin/init.log.' }
    [IO.File]::AppendAllText((Join-Path $data 'postgresql.conf'), "`nlisten_addresses = '127.0.0.1'`nport = $DatabasePort`nlog_statement = 'none'`nlog_min_error_statement = 'panic'`n",$utf8)
    & (Join-Path $pgBin 'pg_ctl.exe') register -N BudgetismDatabase -D $data -S demand *> (Join-Path $admin 'register.log')
    if ($LASTEXITCODE -ne 0) { throw 'Database service registration failed.' }
    $createdDatabaseService = $true
    Invoke-ServiceCommand @('config','BudgetismDatabase','obj=','NT SERVICE\BudgetismDatabase')
    $apiExe = Join-Path $destination 'api\Budgetism.Api.exe'
    $null = New-Service -Name BudgetismApi -BinaryPathName ('"'+$apiExe+'"') -DisplayName 'Budgetism private API' -StartupType Manual -DependsOn BudgetismDatabase
    $createdApiService = $true
    Invoke-ServiceCommand @('config','BudgetismApi','obj=','NT SERVICE\BudgetismApi')
    Set-PrivateDirectory $destination @{'NT SERVICE\BudgetismApi'='ReadAndExecute';'NT SERVICE\BudgetismDatabase'='ReadAndExecute'}
    Set-PrivateDirectory $admin @{}
    Set-PrivateDirectory $secrets @{'NT SERVICE\BudgetismApi'='ReadAndExecute'}
    Set-PrivateDirectory $data @{'NT SERVICE\BudgetismDatabase'='Modify'}
    Start-Service BudgetismDatabase
    (Get-Service BudgetismDatabase).WaitForStatus('Running',[TimeSpan]::FromSeconds(30))
    $passFile = Join-Path $admin 'pgpass'
    [IO.File]::WriteAllText($passFile,"127.0.0.1:${DatabasePort}:*:budgetism_admin:$adminPassword",$utf8)
    [Environment]::SetEnvironmentVariable('PGPASSFILE',$passFile,'Process')
    [Environment]::SetEnvironmentVariable('PGOPTIONS','-c log_statement=none -c log_min_error_statement=panic','Process')
    # Generated passwords contain hex only and never appear in process arguments.
    $sql = "CREATE ROLE budgetism_app LOGIN PASSWORD '$appPassword' NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION;`nCREATE DATABASE budgetism OWNER budgetism_app;`nREVOKE ALL ON DATABASE budgetism FROM PUBLIC;"
    $sql | & (Join-Path $pgBin 'psql.exe') -X -w -h 127.0.0.1 -p $DatabasePort -U budgetism_admin -d postgres -v ON_ERROR_STOP=1 *> (Join-Path $admin 'database-setup.log')
    if ($LASTEXITCODE -ne 0) { throw 'Database role setup failed; see protected database-setup.log.' }
    $environment = @(
        "DB_PASSWORD_FILE=$(Join-Path $secrets 'database-password')",'DB_HOST=127.0.0.1',"DB_PORT=$DatabasePort",
        'DB_NAME=budgetism','DB_USER=budgetism_app',"ASPNETCORE_URLS=http://127.0.0.1:$ApiPort",
        'ASPNETCORE_ENVIRONMENT=Production','BOOTSTRAP_TOKEN_FILE=','ConnectionStrings__Finance=',
        'Logging__LogLevel__Default=Warning','Logging__LogLevel__Microsoft=Warning'
    )
    $null = New-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Services\BudgetismApi' -Name Environment -PropertyType MultiString -Value $environment
    Start-Service BudgetismApi
    Assert-Health
    $status = Invoke-RestMethod -Uri "http://127.0.0.1:$ApiPort/api/setup/status"
    if ($status.initialized) { throw 'Unexpected owner in a new database.' }
    # Prove persistence of service configuration through an orderly restart.
    Stop-Service BudgetismApi
    Restart-Service BudgetismDatabase
    Start-Service BudgetismApi
    Assert-Health
    Set-Service BudgetismDatabase -StartupType Automatic
    Set-Service BudgetismApi -StartupType Automatic
    [ordered]@{format=1;installedUtc=[DateTime]::UtcNow.ToString('o');apiPort=$ApiPort;databasePort=$DatabasePort;mode='loopback-development';ownerInitialized=$false} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $admin 'installation.json') -Encoding UTF8
    Write-Output 'PASS: Database and API run as separate virtual service accounts.'
    Write-Output 'PASS: API health and orderly service restart.'
    Write-Output 'PASS: Empty database; owner enrollment disabled until secure setup.'
    Write-Output "Installed loopback-only development services at $destination"
    Write-Output 'IIS, firewall, Plaid and existing financial workspaces were not changed.'
} catch {
    # Preserve all data for diagnosis. Never delete a cluster or existing service.
    if ($createdApiService) { Stop-Service BudgetismApi -ErrorAction SilentlyContinue; Set-Service BudgetismApi -StartupType Manual -ErrorAction SilentlyContinue }
    if ($createdDatabaseService) { Stop-Service BudgetismDatabase -ErrorAction SilentlyContinue; Set-Service BudgetismDatabase -StartupType Manual -ErrorAction SilentlyContinue }
    throw
} finally {
    [Environment]::SetEnvironmentVariable('PGPASSFILE',$oldPassFile,'Process')
    [Environment]::SetEnvironmentVariable('PGOPTIONS',$oldOptions,'Process')
    $adminPassword = $appPassword = $sql = $null
}
