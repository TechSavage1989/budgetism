# Admin-context API-only coordinator. No scheduler, installer or schema migration.
[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][string]$InstallDirectory,
 [string]$Archive = '', [string]$ArchiveSha256 = '',
 [string]$ExpectedCurrentVersion = '', [string]$CurrentManifest = '', [string]$CurrentManifestSha256 = '',
 [string]$ExpectedSchemaSha256 = '', [string]$HealthUri = '', [string]$DatabaseAdminPassFile = '', [string]$DatabaseAdminUser = '',
 [switch]$Recover
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Add-Type -AssemblyName System.IO.Compression.FileSystem
$utf8 = New-Object Text.UTF8Encoding $false
$tables = @('Owners','Sessions','LedgerAccounts','JournalEntries','LedgerPostings','OperationRecords','ChangeRecords','BankConnections','BankAccounts','BankSources','BankSourceRevisions','BankBatches','BankEvents','BankSchemaVersions','PlanningSchemaVersions','PlanningWorkspaces','PlanningEvents')
function Assert-PlainPath([string]$Path) {
 $full = [IO.Path]::GetFullPath($Path)
 if ($full.StartsWith('\\') -or $full -match '["\r\n]' -or $full.Length -lt 8) { throw 'Use a local non-root path.' }
 $cursor = $full
 while ($cursor) {
  if (Test-Path -LiteralPath $cursor) {
   $item = Get-Item -LiteralPath $cursor -Force
   if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Reparse paths are refused.' }
  }
  $parent = Split-Path $cursor -Parent
  if ($parent -eq $cursor) { break }; $cursor = $parent
 }
 return $full.TrimEnd('\')
}
function Hash([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Read-BoundedBytes([string]$Path,[int]$Limit) {
 $stream=[IO.File]::Open($Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
 try {
  if ($stream.Length -gt $Limit) { throw 'Control file exceeds size limit.' }
  $bytes=New-Object byte[] ([int]$stream.Length); $offset=0
  while ($offset -lt $bytes.Length) { $read=$stream.Read($bytes,$offset,$bytes.Length-$offset); if ($read -eq 0) { throw 'Control file truncated.' }; $offset+=$read }
  return ,$bytes
 } finally { $stream.Dispose() }
}
function Read-BoundedJson([string]$Path,[int]$Limit) {
 $decoder=New-Object Text.UTF8Encoding $false,$true
 return $decoder.GetString((Read-BoundedBytes $Path $Limit)).TrimStart([char]0xfeff) | ConvertFrom-Json
}
function Assert-Digest([string]$Value) { if ($Value -notmatch '^[a-fA-F0-9]{64}$') { throw 'An exact SHA-256 digest is required.' } }
function Assert-Contract($m) {
 foreach ($name in @('format','apiMajor','clientApiContract','bankSchema','planningSchema','updateContract')) {
  if (($m.$name -isnot [int] -and $m.$name -isnot [long]) -or $m.$name -ne 1) { throw 'Compatibility fields must be exact JSON integers.' }
 }
 if ($m.format -ne 1 -or $m.appId -ne 'budgetism-api' -or $m.runtime -ne 'win-x64' -or $m.apiMajor -ne 1 -or $m.clientApiContract -ne 1 -or $m.bankSchema -ne 1 -or $m.planningSchema -ne 1 -or $m.updateContract -ne 1 -or $m.requiresMigration -isnot [bool] -or $m.requiresMigration -ne $false -or $m.version -notmatch '^0\.1\.0-dev\.[0-9]+$' -or $m.sourceCommit -notmatch '^[a-f0-9]{40}$') { throw 'Unsupported API update identity or compatibility contract.' }
}
function Assert-Member([string]$Name) {
 if ($Name -notmatch '^api/[A-Za-z0-9_.+-]+$') { throw 'Unsafe API-only package path.' }
 $leaf = $Name.Substring(4)
 if ($leaf -match '^(?i:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|$)' -or $leaf.EndsWith('.') -or $leaf.EndsWith(' ')) { throw 'Reserved Windows package member.' }
 if ($leaf -notmatch '^[A-Za-z0-9_.+-]+\.dll$' -and $leaf -notin @('Budgetism.Api.exe','Budgetism.Api.deps.json','Budgetism.Api.runtimeconfig.json','api-update-contract.json')) { throw 'Forbidden API-only package content.' }
}
function Assert-Files([string]$Root, $m, [string]$ApiDirectoryName = 'api') {
 $seen = @{}
 foreach ($entry in $m.files) {
  if ($entry.path -isnot [string] -or $entry.sha256 -isnot [string] -or ($entry.size -isnot [int] -and $entry.size -isnot [long]) -or $entry.size -gt 1073741824) { throw 'Manifest members require exact path, digest and integer size types.' }
  Assert-Member $entry.path; Assert-Digest $entry.sha256
  if ($seen.ContainsKey($entry.path) -or [long]$entry.size -lt 0) { throw 'Duplicate or invalid API manifest member.' }
  $seen[$entry.path] = $true
  $path = Assert-PlainPath (Join-Path (Join-Path $Root $ApiDirectoryName) $entry.path.Substring(4))
  if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or (Get-Item -LiteralPath $path).Length -ne [long]$entry.size -or (Hash $path) -ne $entry.sha256) { throw 'API manifest file identity mismatch.' }
 }
 foreach ($required in @('api/Budgetism.Api.exe','api/Budgetism.Api.dll','api/Budgetism.Api.deps.json','api/Budgetism.Api.runtimeconfig.json','api/api-update-contract.json')) {
  if (-not $seen.ContainsKey($required)) { throw 'Required API member missing.' }
 }
 if (@(Get-ChildItem -LiteralPath (Join-Path $Root $ApiDirectoryName) -Directory -Force).Count -ne 0) { throw 'Nested or reparse API directories are refused.' }
 $actual = @(Get-ChildItem -LiteralPath (Join-Path $Root $ApiDirectoryName) -Recurse -File -Force)
 if ($actual.Count -ne $seen.Count) { throw 'Unmanifested API files are refused.' }
 foreach ($file in $actual) {
  $name = 'api/'+$file.FullName.Substring((Join-Path $Root $ApiDirectoryName).Length+1).Replace('\','/')
  if (-not $seen.ContainsKey($name)) { throw 'Unmanifested API file.' }
 }
 $inner = Read-BoundedJson (Join-Path (Join-Path $Root $ApiDirectoryName) 'api-update-contract.json') 16384
 Assert-Contract $inner
 foreach ($key in @('version','sourceCommit','apiMajor','clientApiContract','bankSchema','planningSchema','updateContract')) { if ($inner.$key -ne $m.$key) { throw 'Inner API identity differs from manifest.' } }
}
function Assert-ProgramAcl([string]$Directory,[bool]$Recurse=$true) {
 $principals=@('S-1-5-18','S-1-5-32-544',[Security.Principal.WindowsIdentity]::GetCurrent().User.Value)
 $writeMask=[Security.AccessControl.FileSystemRights]::Write -bor [Security.AccessControl.FileSystemRights]::Delete -bor [Security.AccessControl.FileSystemRights]::ChangePermissions -bor [Security.AccessControl.FileSystemRights]::TakeOwnership -bor [Security.AccessControl.FileSystemRights]::DeleteSubdirectoriesAndFiles
 $items=@(Get-Item -LiteralPath $Directory -Force)
 if ($Recurse) { $items+=@(Get-ChildItem -LiteralPath $Directory -Recurse -Force) }
 foreach ($item in $items) {
  if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Program path contains a reparse point.' }
  foreach ($rule in (Get-Acl -LiteralPath $item.FullName).Access) {
   if ($rule.AccessControlType -eq 'Allow' -and (($rule.FileSystemRights -band $writeMask) -ne 0) -and $rule.IdentityReference.Translate([Security.Principal.SecurityIdentifier]).Value -notin $principals) { throw 'Program directory grants unexpected write access; no ACL changes attempted.' }
  }
 }
}
function Service-Fingerprint {
 $s = Get-CimInstance Win32_Service -Filter "Name='BudgetismApi'"
 if ($null -eq $s) { throw 'Existing BudgetismApi service required; installer is never invoked.' }
 if ($s.PathName.Trim('"') -ne (Join-Path $root 'api\Budgetism.Api.exe') -or $s.StartName -ne 'NT SERVICE\BudgetismApi') { throw 'Unknown service path/identity; separate bootstrap inspection required.' }
 $registry = Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Services\BudgetismApi'
 if (@($registry.DependOnService).Count -ne 1 -or @($registry.DependOnService)[0] -ne 'BudgetismDatabase') { throw 'Unknown service dependencies; separate inspection required.' }
 $encoded = [Text.Encoding]::UTF8.GetBytes((@($s.PathName,$s.StartName,$s.StartMode,(@($registry.DependOnService) -join "`n"),(@($registry.Environment) -join "`n")) -join "`0"))
 $sha = [Security.Cryptography.SHA256]::Create()
 try { return ([BitConverter]::ToString($sha.ComputeHash($encoded))).Replace('-','').ToLowerInvariant() } finally { $sha.Dispose() }
}
function Write-Journal([string]$Phase) {
 $journal.phase = $Phase
 $temp = $journalPath+'.tmp'
 [IO.File]::WriteAllText($temp,($journal | ConvertTo-Json -Depth 5),$utf8)
 if (Test-Path -LiteralPath $journalPath) { [IO.File]::Replace($temp,$journalPath,$null) } else { [IO.File]::Move($temp,$journalPath) }
}
function Stop-Api {
 $service = Get-CimInstance Win32_Service -Filter "Name='BudgetismApi'"
 $pidBefore = [int]$service.ProcessId
 Stop-Service -Name BudgetismApi
 (Get-Service BudgetismApi).WaitForStatus('Stopped',[TimeSpan]::FromSeconds(30))
 if ($pidBefore -gt 0) {
  $process = Get-Process -Id $pidBefore -ErrorAction SilentlyContinue
  if ($null -ne $process -and -not $process.WaitForExit(30000)) { throw 'API process did not exit; no replacement attempted.' }
 }
}
function Readiness([string]$Version,[bool]$Maintenance,[string]$SourceCommit) {
 for ($i=0;$i -lt 30;$i++) {
  try {
   $r = Invoke-RestMethod -Uri $HealthUri -TimeoutSec 3 -MaximumRedirection 0
   $service = Get-CimInstance Win32_Service -Filter "Name='BudgetismApi'"
   $listeners = @(Get-NetTCPConnection -State Listen -LocalPort $healthPort -ErrorAction SilentlyContinue)
   if ($r.appId -eq 'budgetism-api' -and $r.version -eq $Version -and $r.sourceCommit -eq $SourceCommit -and $r.ready -eq $true -and $r.database -eq 'ready' -and $r.updateContract -eq 1 -and $r.apiMajor -eq 1 -and $r.bankSchema -eq 1 -and $r.planningSchema -eq 1 -and $r.maintenance -eq $Maintenance -and $service.State -eq 'Running' -and $listeners.Count -gt 0 -and @($listeners | Where-Object OwningProcess -ne $service.ProcessId).Count -eq 0) { return }
  } catch { }
  Start-Sleep -Seconds 1
 }
 throw 'Exact API version/schema readiness failed.'
}
function Sql([string]$Database,[string]$Statement) {
 $result = $Statement | & (Join-Path $pgBin 'psql.exe') -X -w -h 127.0.0.1 -p $dbPort -U $DatabaseAdminUser -d $Database -At -v ON_ERROR_STOP=1 2> (Join-Path $operation 'database-error.log')
 if ($LASTEXITCODE -ne 0) { throw 'Protected database verification failed; API program was not accepted.' }
 return @($result) -join "`n"
}
function Text-Hash([string]$Value) {
 $sha=[Security.Cryptography.SHA256]::Create()
 try { return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Value)))).Replace('-','').ToLowerInvariant() } finally { $sha.Dispose() }
}
function Data-Proof([string]$Database) {
 $parts = @()
 foreach ($table in $tables) { $parts += Sql $Database ('SELECT count(*)::text || ' + "':'" + ' || md5(COALESCE(string_agg(row_to_json(t)::text, chr(10) ORDER BY row_to_json(t)::text), ' + "''" + ')) FROM "'+$table+'" t;') }
 return $parts -join '|'
}
function Schema-Proof([string]$Database) {
 return Sql $Database "SELECT md5(string_agg(value,chr(10) ORDER BY value)) FROM (SELECT 'column:'||table_name||':'||column_name||':'||data_type||':'||udt_name||':'||is_nullable||':'||COALESCE(column_default,'') AS value FROM information_schema.columns WHERE table_schema='public' UNION ALL SELECT 'index:'||tablename||':'||indexname||':'||indexdef FROM pg_indexes WHERE schemaname='public' UNION ALL SELECT 'constraint:'||c.conrelid::regclass::text||':'||c.conname||':'||pg_get_constraintdef(c.oid) FROM pg_constraint c JOIN pg_namespace n ON n.oid=c.connamespace WHERE n.nspname='public') s;"
}
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Existing administrator maintenance context required; no elevation or service creation is performed.' }
$root = Assert-PlainPath $InstallDirectory
$admin = Assert-PlainPath (Join-Path $root 'admin')
if (-not (Test-Path -LiteralPath $admin -PathType Container)) { throw 'Existing protected admin directory required.' }
$allowed = @('S-1-5-18','S-1-5-32-544',[Security.Principal.WindowsIdentity]::GetCurrent().User.Value)
foreach ($rule in (Get-Acl -LiteralPath $admin).Access) {
 if ($rule.AccessControlType -eq 'Allow' -and $rule.IdentityReference.Translate([Security.Principal.SecurityIdentifier]).Value -notin $allowed) { throw 'Admin directory grants unexpected access; no ACL changes attempted.' }
}
$lock = [IO.File]::Open((Join-Path $admin 'api-update.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
$journalPath = Join-Path $admin 'api-update-journal.json'
$marker = Join-Path $root 'update-maintenance.json'
$oldPass = $env:PGPASSFILE; $oldPassword = $env:PGPASSWORD
try {
 $fingerprint = Service-Fingerprint
 if (Test-Path -LiteralPath $journalPath) {
  $prior = Read-BoundedJson $journalPath 16384
  if ($prior.phase -notin @('Committed','RolledBack')) { throw 'Interrupted API update found. Preserve the journal and program folders; use reviewed recovery. No automatic database restore is permitted.' }
 }
 if ($Recover) { throw 'Automatic interruption recovery is intentionally unavailable; reviewed program-only recovery is required.' }
 if (Test-Path -LiteralPath $marker) { throw 'Unexpected maintenance marker; separate inspection required.' }
 foreach ($digest in @($ArchiveSha256,$CurrentManifestSha256,$ExpectedSchemaSha256)) { Assert-Digest $digest }
 $Archive = Assert-PlainPath $Archive; $CurrentManifest = Assert-PlainPath $CurrentManifest
 if ((Hash $Archive) -ne $ArchiveSha256 -or (Hash $CurrentManifest) -ne $CurrentManifestSha256) { throw 'Pinned archive/current manifest digest mismatch.' }
 $manifestBytes=Read-BoundedBytes $CurrentManifest 1048576
 $manifestHash=[Security.Cryptography.SHA256]::Create()
 try { $actualManifestHash=([BitConverter]::ToString($manifestHash.ComputeHash($manifestBytes))).Replace('-','').ToLowerInvariant() } finally { $manifestHash.Dispose() }
 if ($actualManifestHash -ne $CurrentManifestSha256) { throw 'Current manifest changed during validation.' }
 $decoder=New-Object Text.UTF8Encoding $false,$true
 $current = $decoder.GetString($manifestBytes).TrimStart([char]0xfeff) | ConvertFrom-Json
 Assert-Contract $current
 if ($current.version -ne $ExpectedCurrentVersion) { throw 'Installed version is unknown; separate bootstrap inspection required.' }
 Assert-Files $root $current
 Assert-ProgramAcl $root $false; Assert-ProgramAcl (Join-Path $root 'api')
 $health = [Uri]$HealthUri
 if ($health.Scheme -notin @('http','https') -or $health.Host -notin @('127.0.0.1','::1') -or $health.AbsolutePath -ne '/health/update-readiness' -or $health.UserInfo -or $health.Query -or $health.Fragment) { throw 'Explicit direct loopback readiness URL required.' }
 $healthPort = $health.Port
 Readiness $ExpectedCurrentVersion $false $current.sourceCommit
 $environment = @{}
 foreach ($entry in (Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Services\BudgetismApi').Environment) {
  $pair = $entry -split '=',2; if ($pair.Length -eq 2) { $environment[$pair[0]]=$pair[1] }
 }
 if ($environment['DB_HOST'] -ne '127.0.0.1' -or $environment['DB_NAME'] -notmatch '^[A-Za-z0-9_]+$' -or $environment['ConnectionStrings__Finance']) { throw 'Unknown database connection configuration; inspect separately.' }
 $dbName=$environment['DB_NAME']; $dbPort=[int]$environment['DB_PORT']
 if ($dbPort -lt 1024 -or $dbPort -gt 65535 -or $DatabaseAdminUser -notmatch '^[A-Za-z0-9_]+$') { throw 'Explicit existing database administrative context required.' }
 $DatabaseAdminPassFile=Assert-PlainPath $DatabaseAdminPassFile
 if (-not $DatabaseAdminPassFile.StartsWith($admin+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Use the existing protected administrative password file.' }
 $planningKey=Assert-PlainPath $environment['PLANNING_KEY_FILE']
 $pgBin=Assert-PlainPath (Join-Path $root 'postgresql\bin')
 $operation=Join-Path $admin ('update-'+[Guid]::NewGuid().ToString('N')); $null=New-Item -ItemType Directory $operation
 $env:PGPASSFILE=$DatabaseAdminPassFile; $env:PGPASSWORD=$null
 if ((Text-Hash (Schema-Proof $dbName)) -ne $ExpectedSchemaSha256) { throw 'Installed schema fingerprint differs from approved baseline; service left unchanged.' }
 $stage=Join-Path $root ('api.stage.'+[Guid]::NewGuid().ToString('N')); $null=New-Item -ItemType Directory $stage
 $snapshot=Join-Path $operation 'candidate.zip'
 if ((Get-Item -LiteralPath $Archive).Length -gt 536870912) { throw 'API archive exceeds size limit.' }
 $sourceStream=[IO.File]::Open($Archive,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
 try {
  if ($sourceStream.Length -gt 536870912) { throw 'API archive exceeds size limit.' }
  $destinationStream=[IO.File]::Open($snapshot,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
  try { $sourceStream.CopyTo($destinationStream) } finally { $destinationStream.Dispose() }
 } finally { $sourceStream.Dispose() }
 $archiveStream=[IO.File]::Open($snapshot,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
 $snapshotHash=[Security.Cryptography.SHA256]::Create()
 try { $actualArchiveHash=([BitConverter]::ToString($snapshotHash.ComputeHash($archiveStream))).Replace('-','').ToLowerInvariant() } finally { $snapshotHash.Dispose() }
 if ($actualArchiveHash -ne $ArchiveSha256) { $archiveStream.Dispose(); throw 'Pinned archive snapshot digest mismatch.' }
 $archiveStream.Position=0
 $zip=[IO.Compression.ZipArchive]::new($archiveStream,[IO.Compression.ZipArchiveMode]::Read,$false)
 try {
  $seen=@{}; [long]$total=0
  if ($zip.Entries.Count -gt 5000) { throw 'API archive entry limit exceeded.' }
  foreach ($entry in $zip.Entries) {
   if ($entry.FullName -eq 'api/') { continue }
   if ($entry.FullName -ne 'update-manifest.json') { Assert-Member $entry.FullName }
   if (($entry.FullName -eq 'update-manifest.json' -and $entry.Length -gt 1048576) -or ($entry.FullName -eq 'api/api-update-contract.json' -and $entry.Length -gt 16384)) { throw 'API control file exceeds size limit.' }
   if ($seen.ContainsKey($entry.FullName)) { throw 'Repeated ZIP member.' }; $seen[$entry.FullName]=$true
   $total += $entry.Length; if ($total -gt 1073741824) { throw 'API archive size limit exceeded.' }
   $target=Join-Path $stage $entry.FullName; $null=New-Item -ItemType Directory (Split-Path $target -Parent) -Force
   [IO.Compression.ZipFileExtensions]::ExtractToFile($entry,$target,$false)
  }
 } finally { $zip.Dispose() }
 $candidate=Read-BoundedJson (Join-Path $stage 'update-manifest.json') 1048576
 Assert-Contract $candidate; Assert-Files $stage $candidate; Assert-ProgramAcl $stage
 if ([int]($candidate.version.Split('.')[-1]) -le [int]($current.version.Split('.')[-1])) { throw 'Candidate must be a newer supported development version.' }
 if ($seen.Count -ne @($candidate.files).Count+1) { throw 'Unmanifested archive members.' }
 $rollback=Join-Path $root 'api.rollback'
 $rollbackManifest=Join-Path $admin 'rollback-api-manifest.json'
 $hasPriorRollback=Test-Path -LiteralPath $rollback
 if ($hasPriorRollback) {
  if (-not (Test-Path -LiteralPath $rollbackManifest)) { throw 'Retained rollback identity is unknown; inspect separately.' }
  $priorRollbackContract=Read-BoundedJson $rollbackManifest 1048576
  Assert-Contract $priorRollbackContract; Assert-Files $root $priorRollbackContract 'api.rollback'
 }
 $journal=[ordered]@{format=1;phase='Validated';operation=(Split-Path $operation -Leaf);oldVersion=$current.version;newVersion=$candidate.version;archiveSha256=$ArchiveSha256;serviceFingerprint=$fingerprint}
 Write-Journal 'Validated'
 $originalMoved=$false
 try {
  Stop-Api; Write-Journal 'Stopped'
  $env:PGPASSFILE=$DatabaseAdminPassFile; $env:PGPASSWORD=$null
  $before=Data-Proof $dbName; $schema=Schema-Proof $dbName; $keyHash=Hash $planningKey
  if ((Text-Hash $schema) -ne $ExpectedSchemaSha256) { throw 'Installed schema fingerprint differs from explicitly approved baseline; no migration or replacement attempted.' }
  $dump=Join-Path $operation 'recovery.dump'
  & (Join-Path $pgBin 'pg_dump.exe') -h 127.0.0.1 -p $dbPort -U $DatabaseAdminUser -w -Fc -f $dump $dbName 2> (Join-Path $operation 'dump-error.log')
  if ($LASTEXITCODE -ne 0) { throw 'Protected backup failed.' }
  Copy-Item -LiteralPath $planningKey -Destination (Join-Path $operation 'planning-key')
  if ((Hash (Join-Path $operation 'planning-key')) -ne $keyHash) { throw 'Planning recovery key copy failed.' }
  $restore='budgetism_update_verify_'+[Guid]::NewGuid().ToString('N')
  $null=Sql 'postgres' ('CREATE DATABASE "'+$restore+'";')
  try {
   & (Join-Path $pgBin 'pg_restore.exe') -h 127.0.0.1 -p $dbPort -U $DatabaseAdminUser -w --exit-on-error -d $restore $dump 2> (Join-Path $operation 'restore-error.log')
   if ($LASTEXITCODE -ne 0 -or (Data-Proof $restore) -ne $before -or (Schema-Proof $restore) -ne $schema) { throw 'Independent recovery verification failed.' }
  } finally { $null=Sql 'postgres' ('DROP DATABASE "'+$restore+'";') }
  Assert-Files $stage $candidate; Assert-ProgramAcl $stage
  Assert-Files $root $current; Assert-ProgramAcl (Join-Path $root 'api')
  Write-Journal 'RecoveryVerified'
  [IO.File]::WriteAllText($marker,'{"format":1,"maintenance":true}',$utf8)
  Write-Journal 'Swapping'
  if ($hasPriorRollback) {
   [IO.Directory]::Move($rollback,(Join-Path $operation 'prior-rollback'))
   Copy-Item -LiteralPath $rollbackManifest -Destination (Join-Path $operation 'prior-rollback-manifest.json')
  }
  [IO.Directory]::Move((Join-Path $root 'api'),$rollback)
  $originalMoved=$true
  [IO.Directory]::Move((Join-Path $stage 'api'),(Join-Path $root 'api'))
  Write-Journal 'Swapped'
  Start-Service BudgetismApi
  Readiness $candidate.version $true $candidate.sourceCommit
  if ((Service-Fingerprint) -ne $fingerprint -or (Data-Proof $dbName) -ne $before -or (Schema-Proof $dbName) -ne $schema -or (Hash $planningKey) -ne $keyHash) { throw 'Post-start preservation proof failed.' }
  [IO.File]::WriteAllBytes($rollbackManifest,$manifestBytes)
  Copy-Item -LiteralPath (Join-Path $stage 'update-manifest.json') -Destination (Join-Path $operation 'accepted-manifest.json')
  Write-Journal 'Verified'
  Remove-Item -LiteralPath $marker
  Readiness $candidate.version $false $candidate.sourceCommit
  $activeManifest=Join-Path $admin 'active-api-manifest.json'
  $acceptedBytes=Read-BoundedBytes (Join-Path $operation 'accepted-manifest.json') 1048576
  [IO.File]::WriteAllBytes(($activeManifest+'.tmp'),$acceptedBytes)
  if (Test-Path -LiteralPath $activeManifest) { [IO.File]::Replace(($activeManifest+'.tmp'),$activeManifest,$null) } else { [IO.File]::Move(($activeManifest+'.tmp'),$activeManifest) }
  Write-Journal 'Committed'
  if (Test-Path -LiteralPath (Join-Path $operation 'prior-rollback')) {
   try { Remove-Item -LiteralPath (Join-Path $operation 'prior-rollback') -Recurse -Force }
   catch { Write-Warning 'Upgrade committed; prior rollback cleanup needs reviewed maintenance. Current rollback remains valid.' }
  }
  Write-Output 'PASS: API program updated; existing settings, identities, database, keys and financial data preserved. One program rollback and protected recovery set retained.'
 } catch {
  $failure=$_.Exception
  try {
   Stop-Api
   if ($originalMoved -and (Test-Path -LiteralPath $rollback)) {
    if (Test-Path -LiteralPath (Join-Path $root 'api')) { [IO.Directory]::Move((Join-Path $root 'api'),(Join-Path $operation 'failed-api')) }
    [IO.Directory]::Move($rollback,(Join-Path $root 'api'))
   }
   if (Test-Path -LiteralPath (Join-Path $operation 'prior-rollback')) {
    [IO.Directory]::Move((Join-Path $operation 'prior-rollback'),$rollback)
    Copy-Item -LiteralPath (Join-Path $operation 'prior-rollback-manifest.json') -Destination $rollbackManifest -Force
   }
   if (Test-Path -LiteralPath $marker) { Remove-Item -LiteralPath $marker }
   if ((Service-Fingerprint) -ne $fingerprint) { throw 'Service configuration changed; manual review required.' }
   Start-Service BudgetismApi; Readiness $current.version $false $current.sourceCommit
   [IO.File]::WriteAllBytes((Join-Path $admin 'active-api-manifest.json'),$manifestBytes)
   Write-Journal 'RolledBack'
  } catch { Write-Journal 'RecoveryRequired'; throw 'API update interrupted or rollback failed. Preserve protected journal/program folders. Do not restore the database automatically; reviewed program-only recovery is required.' }
  throw ('API update rejected; previous program restored. No database restore was performed. '+$failure.Message)
 }
} finally { $env:PGPASSFILE=$oldPass; $env:PGPASSWORD=$oldPassword; $lock.Dispose() }
