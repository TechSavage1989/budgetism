# Runs the packaged API against a new fictional database, then stops both processes.
# No installation, firewall changes, IIS changes, or Plaid requests.
[CmdletBinding()]
param(
    [string]$PackageDirectory = '',
    [ValidateRange(1024,65535)][int]$DatabasePort = 55432,
    [ValidateRange(1024,65535)][int]$ApiPort = 55080
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Assert-Check([bool]$Condition, [string]$Description) {
    if (-not $Condition) { throw "Check failed: $Description" }
    Write-Output "PASS: $Description"
}
function New-RandomSecret {
    $bytes = New-Object byte[] 32
    $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
    try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }
    return [Convert]::ToBase64String($bytes)
}
function Invoke-DatabaseControl([string]$Action) {
    $arguments = @('-D', ('"' + $data + '"'), '-w', '-t', '45')
    if ($Action -eq 'start') { $arguments += @('-l', ('"' + (Join-Path $run 'database.log') + '"')) }
    else { $arguments += @('-m', 'fast') }
    $arguments += $Action
    # Do not inherit PowerShell's redirected pipes: the server outlives pg_ctl.
    $control = Start-Process -FilePath (Join-Path $pgBin 'pg_ctl.exe') -ArgumentList $arguments -WindowStyle Hidden -PassThru
    if (-not $control.WaitForExit(55000)) { throw 'Database control timed out.' }
    if ($control.ExitCode -ne 0) { throw 'Database control failed. Inspect database.log.' }
}
function Invoke-Api([string]$Method, [string]$Route, $Body = $null, [string]$Token = '') {
    $parameters = @{ Uri = "$base$Route"; Method = $Method; UseBasicParsing = $true; TimeoutSec = 15 }
    if ($null -ne $Body) { $parameters.Body = ($Body | ConvertTo-Json -Depth 8); $parameters.ContentType = 'application/json' }
    if ($Token) { $parameters.Headers = @{ Authorization = "Bearer $Token" } }
    return Invoke-RestMethod @parameters
}
function Assert-Status([string]$Method, [string]$Route, $Body, [string]$Token, [int]$Expected) {
    $status = 200
    try { $null = Invoke-Api $Method $Route $Body $Token }
    catch {
        if ($null -eq $_.Exception.Response) { throw 'API transport failed.' }
        $status = [int]$_.Exception.Response.StatusCode
    }
    Assert-Check ($status -eq $Expected) "$Route returns $Expected"
}

if ([string]::IsNullOrWhiteSpace($PackageDirectory)) { $PackageDirectory = $PSScriptRoot }
$package = [IO.Path]::GetFullPath($PackageDirectory)
$manifestPath = Join-Path $package 'manifest.json'
if (-not (Test-Path -LiteralPath $manifestPath)) { throw 'Package manifest missing.' }
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if ($manifest.format -ne 1) { throw 'Unsupported package manifest.' }
foreach ($required in @('api/Budgetism.Api.exe','postgresql/bin/initdb.exe','postgresql/bin/pg_ctl.exe','postgresql/bin/postgres.exe','Test-BudgetismServer.ps1')) {
    if (@($manifest.files | Where-Object path -eq $required).Count -ne 1) { throw 'Required package component missing or repeated.' }
}
foreach ($entry in $manifest.files) {
    $path = [IO.Path]::GetFullPath((Join-Path $package $entry.path))
    if (-not $path.StartsWith($package.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe package path.' }
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw 'Package file missing.' }
    if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $entry.sha256) { throw 'Package integrity check failed.' }
}
Assert-Check $true 'Package file hashes'
if ($DatabasePort -eq $ApiPort) { throw 'Ports must differ.' }
foreach ($port in @($DatabasePort,$ApiPort)) {
    $probe = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, $port)
    try { $probe.Start() } catch { throw "Port $port is already occupied; no test started." } finally { $probe.Stop() }
}
$run = Join-Path $package ('runs\' + [Guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $run
$acl = New-Object Security.AccessControl.DirectorySecurity
$acl.SetAccessRuleProtection($true, $false)
foreach ($sid in @([Security.Principal.WindowsIdentity]::GetCurrent().User.Value,'S-1-5-18','S-1-5-32-544')) {
    $identity = [Security.Principal.SecurityIdentifier]::new($sid)
    $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($identity,'FullControl','ContainerInherit,ObjectInherit','None','Allow'))
}
Set-Acl -LiteralPath $run -AclObject $acl
$utf8 = New-Object Text.UTF8Encoding $false
$dbPassword = New-RandomSecret
$ownerPassword = New-RandomSecret
$bootstrap = New-RandomSecret
[IO.File]::WriteAllText((Join-Path $run 'db-password'), $dbPassword, $utf8)
[IO.File]::WriteAllText((Join-Path $run 'bootstrap'), $bootstrap, $utf8)
$data = Join-Path $run 'database'
$pgBin = Join-Path $package 'postgresql\bin'
$base = "http://127.0.0.1:$ApiPort"
$environment = @{
    DB_PASSWORD_FILE = (Join-Path $run 'db-password'); BOOTSTRAP_TOKEN_FILE = (Join-Path $run 'bootstrap')
    DB_HOST = '127.0.0.1'; DB_PORT = [string]$DatabasePort; DB_NAME = 'postgres'; DB_USER = 'budgetism_test'
    ASPNETCORE_URLS = $base; ASPNETCORE_ENVIRONMENT = 'Production'; ConnectionStrings__Finance = $null
    Logging__LogLevel__Default = 'Warning'; Logging__LogLevel__Microsoft = 'Warning'
}
$previous = @{}
$api = $null
$databaseStarted = $false
try {
    $passwordFile = Join-Path $run 'db-password'
    & (Join-Path $pgBin 'initdb.exe') -D $data -U budgetism_test --auth=scram-sha-256 --encoding=UTF8 --locale=C "--pwfile=$passwordFile" *> (Join-Path $run 'init.log')
    if ($LASTEXITCODE -ne 0) { throw 'Database initialization failed. See the restricted local init.log.' }
    [IO.File]::AppendAllText((Join-Path $data 'postgresql.conf'), "`nlisten_addresses = '127.0.0.1'`nport = $DatabasePort`n", $utf8)
    $databaseStarted = $true
    Invoke-DatabaseControl 'start'
    foreach ($key in $environment.Keys) {
        $previous[$key] = [Environment]::GetEnvironmentVariable($key,'Process')
        [Environment]::SetEnvironmentVariable($key,$environment[$key],'Process')
    }
    $api = Start-Process -FilePath (Join-Path $package 'api\Budgetism.Api.exe') -WorkingDirectory (Join-Path $package 'api') -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $run 'api.log') -RedirectStandardError (Join-Path $run 'api-error.log')
    $healthy = $false
    for ($attempt = 0; $attempt -lt 30; $attempt++) {
        if ($api.HasExited) { throw 'API stopped unexpectedly. See its restricted local log.' }
        try { $health = Invoke-Api 'GET' '/health'; $healthy = $health.status -eq 'ok' } catch { }
        if ($healthy) { break }
        Start-Sleep -Seconds 1
    }
    Assert-Check $healthy 'API starts with bundled .NET and isolated PostgreSQL'
    Assert-Status 'GET' '/api/accounts' $null '' 401
    $null = Invoke-Api 'POST' '/api/setup/owner' @{username='fictional_test_owner';password=$ownerPassword;bootstrapToken=$bootstrap}
    Assert-Status 'POST' '/api/bank/sandbox/preview' @{} '' 401
    $auth = Invoke-Api 'POST' '/api/auth/login' @{username='fictional_test_owner';password=$ownerPassword}
    Assert-Status 'POST' '/api/bank/sandbox/preview' @{} $auth.token 503
    $request = @{operationId=[Guid]::NewGuid().ToString();name='Fictional Checking';type='checking';currency='USD';openingBalanceMinor=100000}
    $account = Invoke-Api 'POST' '/api/accounts' $request $auth.token
    $repeat = Invoke-Api 'POST' '/api/accounts' $request $auth.token
    Assert-Check ($account.id -eq $repeat.id -and $account.balanceMinor -eq 100000) 'Account retry preserves identity and exact opening balance'
    $request.openingBalanceMinor = 100001
    Assert-Status 'POST' '/api/accounts' $request $auth.token 409
    $categories = Invoke-Api 'GET' '/api/categories' $null $auth.token
    $expense = $categories | Where-Object kind -eq 'Expense' | Select-Object -First 1
    $transaction = @{operationId=[Guid]::NewGuid().ToString();kind='expense';accountId=$account.id;counterpartyAccountId=$expense.id;amountMinor=8031;currency='USD';effectiveDate='2026-10-29';payee='Fictional Store';notes='Server smoke test only'}
    $saved = Invoke-Api 'POST' '/api/transactions' $transaction $auth.token
    $repeated = Invoke-Api 'POST' '/api/transactions' $transaction $auth.token
    Assert-Check ($saved.id -eq $repeated.id) 'Transaction retry does not duplicate'
    $accounts = @(Invoke-Api 'GET' '/api/accounts' $null $auth.token)
    Assert-Check ($accounts.Count -eq 1 -and $accounts[0].balanceMinor -eq 91969) 'Exact balance after fictional expense'
    $null = Invoke-Api 'POST' '/api/auth/logout' $null $auth.token
    Assert-Status 'GET' '/api/accounts' $null $auth.token 401
    Write-Output 'PASS: Server smoke test complete. No bank connection or persistent service installed.'
} finally {
    if ($null -ne $api -and -not $api.HasExited) { Stop-Process -Id $api.Id; $api.WaitForExit(10000) | Out-Null }
    if ($databaseStarted) {
        Invoke-DatabaseControl 'stop'
    }
    foreach ($key in $previous.Keys) { [Environment]::SetEnvironmentVariable($key,$previous[$key],'Process') }
    $dbPassword = $ownerPassword = $bootstrap = $auth = $null
    Write-Output "Fictional test data and restricted logs retained at: $run"
}
