# Creates only a disposable local PostgreSQL cluster. No services, provider calls, or existing database access.
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$DotnetPath,
    [Parameter(Mandatory=$true)][string]$PostgresDirectory,
    [ValidateRange(1024,65535)][int]$Port = 55434
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($Port -in @(5432,55432)) { throw 'Refusing ordinary database ports.' }
$probe = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,$Port)
try { $probe.Start() } finally { $probe.Stop() }
$repo = Split-Path $PSScriptRoot -Parent
$run = Join-Path $repo ('build\bank-contract-' + [Guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $run
$acl = New-Object Security.AccessControl.DirectorySecurity
$acl.SetAccessRuleProtection($true,$false)
foreach ($sid in @([Security.Principal.WindowsIdentity]::GetCurrent().User.Value,'S-1-5-18','S-1-5-32-544')) {
    $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new([Security.Principal.SecurityIdentifier]::new($sid),'FullControl','ContainerInherit,ObjectInherit','None','Allow'))
}
Set-Acl -LiteralPath $run -AclObject $acl
$utf8 = New-Object Text.UTF8Encoding $false
$bytes = New-Object byte[] 32
$rng = [Security.Cryptography.RandomNumberGenerator]::Create()
try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }
$password = [Convert]::ToBase64String($bytes)
[IO.File]::WriteAllText((Join-Path $run 'password'),$password,$utf8)
[IO.File]::WriteAllText((Join-Path $run 'port'),[string]$Port,$utf8)
[IO.File]::WriteAllText((Join-Path $run 'budgetism-disposable-test'),'fictional cluster only',$utf8)
$pgBin = Join-Path ([IO.Path]::GetFullPath($PostgresDirectory)) 'bin'
$data = Join-Path $run 'data'
$started = $false
$oldPass = $env:PGPASSWORD
$oldPassFile = $env:PGPASSFILE
function Control([string]$Action) {
    $arguments = @('-D',('"'+$data+'"'),'-w','-t','45')
    if ($Action -eq 'start') { $arguments += @('-l',('"'+(Join-Path $run 'database.log')+'"')) }
    else { $arguments += @('-m','fast') }
    $arguments += $Action
    $p = Start-Process -FilePath (Join-Path $pgBin 'pg_ctl.exe') -ArgumentList $arguments -WindowStyle Hidden -PassThru
    if (-not $p.WaitForExit(55000) -or $p.ExitCode -ne 0) { throw 'Disposable database control failed.' }
}
try {
    & (Join-Path $pgBin 'initdb.exe') -D $data -U budgetism_bank_test --auth=scram-sha-256 --encoding=UTF8 --locale=C "--pwfile=$(Join-Path $run 'password')" *> (Join-Path $run 'init.log')
    if ($LASTEXITCODE -ne 0) { throw 'Disposable database initialization failed.' }
    [IO.File]::AppendAllText((Join-Path $data 'postgresql.conf'),"`nlisten_addresses = '127.0.0.1'`nport = $Port`n",$utf8)
    $started = $true
    Control 'start'
    & $DotnetPath run --project (Join-Path $repo 'tests\server-bank-contract\server-bank-contract.csproj') --configuration Release -- --disposable-cluster $run
    if ($LASTEXITCODE -ne 0) { throw 'Server bank contracts failed.' }
    [IO.File]::WriteAllText((Join-Path $run 'pgpass'),"127.0.0.1:${Port}:*:budgetism_bank_test:$password`n",$utf8)
    $env:PGPASSWORD = $null
    $env:PGPASSFILE = Join-Path $run 'pgpass'
    & (Join-Path $pgBin 'pg_dump.exe') -h 127.0.0.1 -p $Port -U budgetism_bank_test -w -Fc -f (Join-Path $run 'fictional.dump') postgres
    if ($LASTEXITCODE -ne 0) { throw 'Fictional backup failed.' }
    & (Join-Path $pgBin 'createdb.exe') -h 127.0.0.1 -p $Port -U budgetism_bank_test -w bank_recovery
    if ($LASTEXITCODE -ne 0) { throw 'Disposable restore database creation failed.' }
    & (Join-Path $pgBin 'pg_restore.exe') -h 127.0.0.1 -p $Port -U budgetism_bank_test -w --exit-on-error -d bank_recovery (Join-Path $run 'fictional.dump')
    if ($LASTEXITCODE -ne 0) { throw 'Fictional restore failed.' }
    Control 'stop'
    $started = $false
    Control 'start'
    $started = $true
    & $DotnetPath run --project (Join-Path $repo 'tests\server-bank-contract\server-bank-contract.csproj') --configuration Release --no-build -- --verify-disposable $run
    if ($LASTEXITCODE -ne 0) { throw 'Restored source/ledger verification failed.' }
    Write-Output 'PASS: Isolated bank contracts completed without live database or Plaid access.'
} finally {
    $env:PGPASSWORD = $oldPass
    $env:PGPASSFILE = $oldPassFile
    if ($started) { Control 'stop' }
}
