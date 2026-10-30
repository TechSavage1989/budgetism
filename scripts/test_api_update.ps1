# Disposable hosted Windows tests only. Synthetic predecessor/future builds are
# test fixtures, not claims that the historical dev.24 installation is upgradeable.
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$DotnetPath,
 [Parameter(Mandatory=$true)][string]$InstallDirectory,
 [Parameter(Mandatory=$true)][ValidatePattern('^[a-f0-9]{40}$')][string]$SourceCommit)
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_OS -ne 'Windows') { throw 'Only the disposable GitHub-hosted Windows test context is supported.' }
$repo=Split-Path $PSScriptRoot -Parent
$root=[IO.Path]::GetFullPath($InstallDirectory).TrimEnd('\')
if ($root -ne [IO.Path]::GetFullPath((Join-Path $repo 'build\private-service'))) { throw 'Only the exact disposable CI service installation is supported.' }
$installed=Get-Content (Join-Path $root 'admin\installation.json') -Raw | ConvertFrom-Json
if ($installed.mode -ne 'loopback-development' -or $installed.ownerInitialized -ne $false) { throw 'Unexpected fixture installation.' }
$work=Join-Path $repo 'build\api-update-tests'; $null=New-Item -ItemType Directory $work
$pg=Join-Path $root 'postgresql\bin'; $pass=Join-Path $root 'admin\pgpass'
$env:PGPASSFILE=$pass; $env:PGPASSWORD=$null
$port=$installed.databasePort
$uri='http://127.0.0.1:'+$installed.apiPort
$utf8=New-Object Text.UTF8Encoding $false
$apiProgram=Join-Path $root 'api'
$originalServicePath=(Get-CimInstance Win32_Service -Filter "Name='BudgetismApi'").PathName
function Check([bool]$Condition,[string]$Description) { if (-not $Condition) { throw "FAIL: $Description" }; Write-Output "PASS: $Description" }
function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function TextHash([string]$Text) { $sha=[Security.Cryptography.SHA256]::Create(); try { ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text)))).Replace('-','').ToLowerInvariant() } finally { $sha.Dispose() } }
function Sql([string]$Statement) {
 $value=$Statement | & (Join-Path $pg 'psql.exe') -X -w -h 127.0.0.1 -p $port -U budgetism_admin -d budgetism -At -v ON_ERROR_STOP=1
 if ($LASTEXITCODE -ne 0) { throw 'Fixture SQL failed.' }; return @($value) -join "`n"
}
function DataProof {
 $tables=@('Owners','Sessions','LedgerAccounts','JournalEntries','LedgerPostings','OperationRecords','ChangeRecords','BankConnections','BankAccounts','BankSources','BankSourceRevisions','BankBatches','BankEvents','BankSchemaVersions','PlanningSchemaVersions','PlanningWorkspaces','PlanningEvents')
 $parts=@(); foreach ($table in $tables) { $parts+=Sql ('SELECT count(*)::text || ' + "':'" + ' || md5(COALESCE(string_agg(row_to_json(t)::text, chr(10) ORDER BY row_to_json(t)::text), ' + "''" + ')) FROM "'+$table+'" t;') }; return $parts -join '|'
}
function SchemaProof { return Sql "SELECT md5(string_agg(value,chr(10) ORDER BY value)) FROM (SELECT 'column:'||table_name||':'||column_name||':'||data_type||':'||udt_name||':'||is_nullable||':'||COALESCE(column_default,'') AS value FROM information_schema.columns WHERE table_schema='public' UNION ALL SELECT 'index:'||tablename||':'||indexname||':'||indexdef FROM pg_indexes WHERE schemaname='public' UNION ALL SELECT 'constraint:'||c.conrelid::regclass::text||':'||c.conname||':'||pg_get_constraintdef(c.oid) FROM pg_constraint c JOIN pg_namespace n ON n.oid=c.connamespace WHERE n.nspname='public') s;" }
function WaitApi([string]$Version) {
 for ($i=0;$i -lt 30;$i++) { try { $r=Invoke-RestMethod "$uri/health/update-readiness" -TimeoutSec 2; if ($r.version -eq $Version -and $r.ready -eq $true -and -not $r.maintenance) { return } } catch {}; Start-Sleep 1 }
 throw 'Fixture API readiness timed out.'
}
function Coordinator([string]$Archive,[string]$Version,[string]$Manifest,[string]$SchemaHash,[string]$ArchiveDigest='',[string]$Target=$apiProgram) {
 if (-not $ArchiveDigest) { $ArchiveDigest=Hash $Archive }
 $output = & powershell.exe -NoProfile -File (Join-Path $repo 'scripts\update_private_server.ps1') -InstallDirectory $root -ApiProgramDirectory $Target -Archive $Archive -ArchiveSha256 $ArchiveDigest -ExpectedCurrentVersion $Version -CurrentManifest $Manifest -CurrentManifestSha256 (Hash $Manifest) -ExpectedSchemaSha256 $SchemaHash -HealthUri "$uri/health/update-readiness" -DatabaseAdminPassFile $pass -DatabaseAdminUser budgetism_admin 2> (Join-Path $work 'last-error.txt')
 $code=$LASTEXITCODE
 foreach ($line in @($output)) { Write-Host $line }
 return $code
}
try {
 Start-Service BudgetismDatabase
 (Get-Service BudgetismDatabase).WaitForStatus('Running',[TimeSpan]::FromSeconds(30))
 # All synthetic package versions compile the actual current source and API
 # contract; only their assembly version differs to exercise ordered upgrades.
 foreach ($n in @(26,27,28)) {
  & (Join-Path $repo 'scripts\package_api_update.ps1') -DotnetPath $DotnetPath -OutputDirectory (Join-Path $work "v$n") -SourceCommit $SourceCommit -Version "0.1.0-dev.$n"
  if ($LASTEXITCODE -ne 0) { throw 'Synthetic API package failed.' }
  & python (Join-Path $repo 'scripts\archive_api_update.py') (Join-Path $work "v$n") (Join-Path $work "v$n.zip")
  if ($LASTEXITCODE -ne 0) { throw 'Synthetic API archive failed.' }
 }
 Stop-Service BudgetismApi -ErrorAction SilentlyContinue
 (Get-Service BudgetismApi).WaitForStatus('Stopped',[TimeSpan]::FromSeconds(30))
 # Explicit bootstrap is confined to this known empty disposable installation.
 Remove-Item -LiteralPath (Join-Path $root 'api') -Recurse -Force
 Copy-Item -LiteralPath (Join-Path $work 'v26\api') -Destination (Join-Path $root 'api') -Recurse
 $current=Join-Path $root 'admin\fixture-current-manifest.json'
 Copy-Item -LiteralPath (Join-Path $work 'v26\update-manifest.json') -Destination $current
 $null=Sql @'
INSERT INTO "Owners" ("Id","Username","PasswordHash","CreatedUtc") VALUES ('10000000-0000-0000-0000-000000000001','fictional_update_owner','not-an-authenticating-password',now());
INSERT INTO "LedgerAccounts" ("Id","OwnerId","Name","Type","LedgerKind","Currency","IsSystem","Archived","CreatedUtc") VALUES
('20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','Fictional updater cash','checking','Asset','USD',false,false,now()),
('20000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000001','Fictional opening equity','equity','Equity','USD',true,false,now());
INSERT INTO "JournalEntries" ("Id","OwnerId","OperationId","Kind","EffectiveDate","AmountMinor","Currency","PrimaryAccountId","CounterpartyAccountId","Payee","Notes","Version","CreatedUtc") VALUES
('30000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001','opening','2026-10-30',12345,'USD','20000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000002','','',1,now());
INSERT INTO "LedgerPostings" ("Id","JournalEntryId","LedgerAccountId","OwnerId","AmountMinor") VALUES
('50000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001',12345),
('50000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000001',-12345);
'@
 $before=DataProof; $schema=TextHash (SchemaProof)
 $keyHash=Hash (Join-Path $root 'api-secrets\planning-key')
 $serviceEnvironment=(Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\BudgetismApi').Environment | ConvertTo-Json -Compress
 Start-Service BudgetismApi; WaitApi '0.1.0-dev.26'
 $pidBefore=(Get-CimInstance Win32_Service -Filter "Name='BudgetismApi'").ProcessId
 $mismatchedTarget=Join-Path $root 'api-abcdefabcdef'
 $null=New-Item -ItemType Directory $mismatchedTarget
 $junctionTarget=Join-Path $root 'api-fedcbafedcba'
 $null=New-Item -ItemType Junction -Path $junctionTarget -Target $apiProgram
 foreach ($invalid in @($junctionTarget,(Join-Path $root 'admin'),(Join-Path $root 'api\nested'),(Join-Path $work 'api'),(Join-Path $root 'api-abcdefabcdef'))) {
  $code=Coordinator (Join-Path $work 'v27.zip') '0.1.0-dev.26' $current $schema '' $invalid
  Check ($code -ne 0 -and (Get-CimInstance Win32_Service -Filter "Name='BudgetismApi'").ProcessId -eq $pidBefore) 'Invalid or mismatched target refuses before service stop'
 }
 $code=Coordinator (Join-Path $work 'v27.zip') '0.1.0-dev.26' $current $schema ('0'*64)
 Check ($code -ne 0 -and (Get-CimInstance Win32_Service -Filter "Name='BudgetismApi'").ProcessId -eq $pidBefore) 'Tampered archive digest refused before service stop'
 $code=Coordinator (Join-Path $work 'v27.zip') '0.1.0-dev.1' $current $schema
 Check ($code -ne 0 -and (Get-CimInstance Win32_Service -Filter "Name='BudgetismApi'").ProcessId -eq $pidBefore) 'Unknown legacy version refuses automatic bootstrap'
 $code=Coordinator (Join-Path $work 'v27.zip') '0.1.0-dev.26' $current ('0'*64)
 Check ($code -ne 0 -and (Get-CimInstance Win32_Service -Filter "Name='BudgetismApi'").ProcessId -eq $pidBefore) 'Unapproved schema fingerprint refused before stop'
 $null=Sql 'UPDATE "PlanningSchemaVersions" SET "Version"=2 WHERE "Id"=1;'
 try {
  $code=Coordinator (Join-Path $work 'v27.zip') '0.1.0-dev.26' $current $schema
  Check ($code -ne 0 -and (Get-CimInstance Win32_Service -Filter "Name='BudgetismApi'").ProcessId -eq $pidBefore) 'Future planning schema refuses before service stop'
 } finally { $null=Sql 'UPDATE "PlanningSchemaVersions" SET "Version"=1 WHERE "Id"=1;' }
 $forbidden=Join-Path $work 'forbidden'; Copy-Item -LiteralPath (Join-Path $work 'v27') -Destination $forbidden -Recurse
 [IO.File]::WriteAllText((Join-Path $forbidden 'migration.sql'),'-- never executed',$utf8)
 Compress-Archive -Path (Join-Path $forbidden '*') -DestinationPath (Join-Path $work 'forbidden.zip')
 $code=Coordinator (Join-Path $work 'forbidden.zip') '0.1.0-dev.26' $current $schema
 Check ($code -ne 0 -and (Get-CimInstance Win32_Service -Filter "Name='BudgetismApi'").ProcessId -eq $pidBefore) 'Unmanifested migration content refused before stop'
 # A real incomplete HTTP body holds an admitted request without a production
 # delay hook. The maintenance gate must not hide this in-flight work.
 $held=New-Object Net.Sockets.TcpClient
 try {
  $held.Connect('127.0.0.1',[int]$installed.apiPort)
  $stream=$held.GetStream()
  $bytes=[Text.Encoding]::ASCII.GetBytes("POST /api/auth/login HTTP/1.1`r`nHost: localhost`r`nContent-Type: application/json`r`nContent-Length: 2`r`nConnection: close`r`n`r`n{")
  $stream.Write($bytes,0,$bytes.Length); $stream.Flush()
  $seen=$false
  for ($i=0;$i -lt 20;$i++) {
   $r=Invoke-RestMethod "$uri/health/update-readiness" -TimeoutSec 2
   if ($r.activeRequests -eq 1) { $seen=$true; break }
   Start-Sleep -Milliseconds 100
  }
  Check $seen 'Incomplete real request is tracked before its handler finishes'
  $marker=Join-Path $root 'update-maintenance.json'; [IO.File]::WriteAllText($marker,'malformed marker remains fail-closed',$utf8)
  $r=Invoke-RestMethod "$uri/health/update-readiness" -TimeoutSec 2
  Check ($r.maintenance -eq $true -and $r.activeRequests -eq 1) 'Maintenance cannot report drained while prior work is active'
 } finally { $held.Dispose() }
 for ($i=0;$i -lt 30;$i++) {
  $r=Invoke-RestMethod "$uri/health/update-readiness" -TimeoutSec 2
  if ($r.activeRequests -eq 0) { break }
  Start-Sleep -Milliseconds 100
 }
 Check ($r.activeRequests -eq 0) 'Aborted body releases the admission counter in finally'

 foreach ($route in @('/api/auth/login','/api/setup/owner','/api/transactions','/api/planning/command')) {
  $status=0; try { Invoke-RestMethod "$uri$route" -Method Post -ContentType 'application/json' -Body '{}' | Out-Null } catch { $status=[int]$_.Exception.Response.StatusCode }
  Check ($status -eq 503) 'Maintenance blocks authentication and financial mutation before handlers'
 }
 $drained=Invoke-RestMethod "$uri/health/update-readiness"
 Check ($drained.maintenance -eq $true -and $drained.activeRequests -eq 0) 'Readiness excludes itself and rejected requests drain to zero'
 Check ((DataProof) -eq $before) 'Maintenance attempts preserve every table'
 Remove-Item -LiteralPath $marker
 foreach ($n in @(27,28)) {
  $prior=$n-1
  $code=Coordinator (Join-Path $work "v$n.zip") "0.1.0-dev.$prior" $current $schema
  Check ($code -eq 0) "Verified API-only v$prior to v$n upgrade"
  WaitApi "0.1.0-dev.$n"
  Check ((DataProof) -eq $before -and (Hash (Join-Path $root 'api-secrets\planning-key')) -eq $keyHash) 'Upgrade preserves all17 table contents and planning key'
  Check (((Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\BudgetismApi').Environment | ConvertTo-Json -Compress) -eq $serviceEnvironment) 'Service environment preserved byte-for-byte'
  $current=Join-Path $root 'admin\active-api-manifest.json'
  Check ((Hash $current) -eq (Hash (Join-Path $work "v$n\update-manifest.json"))) 'Next update uses protected accepted manifest identity'
 }
 # Deliberately inconsistent synthetic package: manifest claims29 but binary is28.
 # File hashes remain valid, so only the exact post-start runtime check can reject it.
 $bad=Join-Path $work 'bad-health'; Copy-Item -LiteralPath (Join-Path $work 'v28') -Destination $bad -Recurse
 $innerPath=Join-Path $bad 'api\api-update-contract.json'
 $inner=Get-Content $innerPath -Raw | ConvertFrom-Json; $inner.version='0.1.0-dev.29'
 [IO.File]::WriteAllText($innerPath,($inner | ConvertTo-Json -Depth 5),$utf8)
 $manifestPath=Join-Path $bad 'update-manifest.json'; $m=Get-Content $manifestPath -Raw | ConvertFrom-Json; $m.version='0.1.0-dev.29'
 $entry=$m.files | Where-Object path -eq 'api/api-update-contract.json'; $entry.sha256=Hash $innerPath; $entry.size=(Get-Item $innerPath).Length
 [IO.File]::WriteAllText($manifestPath,($m | ConvertTo-Json -Depth 6),$utf8)
 & python (Join-Path $repo 'scripts\archive_api_update.py') $bad (Join-Path $work 'bad-health.zip')
 if ($LASTEXITCODE -ne 0) { throw 'Bad-health fixture archive failed.' }
 $code=Coordinator (Join-Path $work 'bad-health.zip') '0.1.0-dev.28' $current $schema
 Check ($code -ne 0) 'Wrong runtime identity fails health and rolls program back'
 WaitApi '0.1.0-dev.28'
 Check ((DataProof) -eq $before) 'Failed health rollback never restores or loses database contents'
 $journal=Join-Path $root 'admin\api-update-journal.json'; $journalBytes=[IO.File]::ReadAllBytes($journal)
 $pending=Get-Content $journal -Raw | ConvertFrom-Json; $pending.phase='Swapping'
 [IO.File]::WriteAllText($journal,($pending | ConvertTo-Json),$utf8)
 $pidBefore=(Get-CimInstance Win32_Service -Filter "Name='BudgetismApi'").ProcessId
 $code=Coordinator (Join-Path $work 'bad-health.zip') '0.1.0-dev.28' $current $schema
 Check ($code -ne 0 -and (Get-CimInstance Win32_Service -Filter "Name='BudgetismApi'").ProcessId -eq $pidBefore) 'Interrupted journal refuses a blind retry or database restore'
 [IO.File]::WriteAllBytes($journal,$journalBytes)
 foreach ($name in @('BudgetismApi','BudgetismDatabase')) {
  $s=Get-CimInstance Win32_Service -Filter "Name='$name'"; Check ($s.StartName -eq "NT SERVICE\$name" -and $s.StartMode -eq 'Auto') 'Existing service identity and startup preserved'
 }
 # A second disposable fixture models the inspected versioned-directory layout.
 # Only this test arranges SCM; the coordinator itself must never change it.
 Stop-Service BudgetismApi
 (Get-Service BudgetismApi).WaitForStatus('Stopped',[TimeSpan]::FromSeconds(30))
 $apiProgram=Join-Path $root 'api-fc02d3d55074'
 Copy-Item -LiteralPath (Join-Path $work 'v26\api') -Destination $apiProgram -Recurse
 & sc.exe config BudgetismApi binPath= ('"'+(Join-Path $apiProgram 'Budgetism.Api.exe')+'"') | Out-Null
 if ($LASTEXITCODE -ne 0) { throw 'Disposable versioned service fixture setup failed.' }
 # Preserve stable-layout evidence before creating a separate known test baseline.
 $null=New-Item -ItemType Directory (Join-Path $work 'stable-layout-receipts')
 foreach ($name in @('api-update-journal.json','active-api-manifest.json','active-api-manifest.json.target.json','rollback-api-manifest.json','rollback-api-manifest.json.target.json')) {
  Move-Item -LiteralPath (Join-Path $root ('admin\'+$name)) -Destination (Join-Path $work ('stable-layout-receipts\'+$name))
 }
 $current=Join-Path $root 'admin\fixture-current-manifest.json'
 Copy-Item -LiteralPath (Join-Path $work 'v26\update-manifest.json') -Destination $current -Force
 $versionedServicePath=(Get-CimInstance Win32_Service -Filter "Name='BudgetismApi'").PathName
 Start-Service BudgetismApi; WaitApi '0.1.0-dev.26'
 foreach ($n in @(27,28)) {
  $prior=$n-1
  $code=Coordinator (Join-Path $work "v$n.zip") "0.1.0-dev.$prior" $current $schema
  Check ($code -eq 0) 'Versioned direct-child target upgrades without changing SCM path'
  WaitApi "0.1.0-dev.$n"
  Check ((Get-CimInstance Win32_Service -Filter "Name='BudgetismApi'").PathName -eq $versionedServicePath) 'Versioned SCM executable path remains exact'
  Check ((DataProof) -eq $before -and (Hash (Join-Path $root 'api-secrets\planning-key')) -eq $keyHash) 'Versioned target preserves financial rows and key'
  Check (((Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\BudgetismApi').Environment | ConvertTo-Json -Compress) -eq $serviceEnvironment) 'Versioned target preserves service environment'
  $current=Join-Path $root 'admin\active-api-manifest.json'
  $receipt=Get-Content ($current+'.target.json') -Raw | ConvertFrom-Json
  Check ($receipt.programDirectory -eq 'api-fc02d3d55074' -and $receipt.manifestSha256 -eq (Hash $current)) 'Accepted receipt binds manifest to exact versioned target'
 }
 $code=Coordinator (Join-Path $work 'bad-health.zip') '0.1.0-dev.28' $current $schema
 Check ($code -ne 0) 'Versioned target failed-health rollback restores original executable path'
 WaitApi '0.1.0-dev.28'
 Check ((DataProof) -eq $before -and (Get-CimInstance Win32_Service -Filter "Name='BudgetismApi'").PathName -eq $versionedServicePath) 'Versioned rollback preserves data and SCM path'
 $receiptPath=$current+'.target.json'; $receiptBytes=[IO.File]::ReadAllBytes($receiptPath)
 $receipt=Get-Content $receiptPath -Raw | ConvertFrom-Json; $receipt.programDirectory='api'
 [IO.File]::WriteAllText($receiptPath,($receipt | ConvertTo-Json),$utf8)
 $pidBefore=(Get-CimInstance Win32_Service -Filter "Name='BudgetismApi'").ProcessId
 $code=Coordinator (Join-Path $work 'bad-health.zip') '0.1.0-dev.28' $current $schema
 Check ($code -ne 0 -and (Get-CimInstance Win32_Service -Filter "Name='BudgetismApi'").ProcessId -eq $pidBefore) 'Foreign target receipt refuses before service stop'
 [IO.File]::WriteAllBytes($receiptPath,$receiptBytes)
 [ordered]@{format=1;scope='Disposable synthetic API program updates only; not live legacy adoption';sequentialUpgrades=4;stableAndVersionedTargets=$true;invalidTargetsRefused=$true;targetBoundReceipt=$true;failedHealthRollback=$true;databaseRestoredOverLive=$false;tableCount=17;maintenanceGate=$true;interruptionRefused=$true;archiveTamperRefused=$true;schemaMismatchRefused=$true;futureSchemaRefused=$true;forbiddenContentRefused=$true;legacyBootstrapRefused=$true} | ConvertTo-Json | Set-Content (Join-Path $work 'verification.json')
} finally {
 Stop-Service BudgetismApi -ErrorAction SilentlyContinue
 (Get-Service BudgetismApi).WaitForStatus('Stopped',[TimeSpan]::FromSeconds(30))
 & sc.exe config BudgetismApi binPath= $originalServicePath | Out-Null
 Stop-Service BudgetismDatabase -ErrorAction SilentlyContinue
 $env:PGPASSFILE=$null; $env:PGPASSWORD=$null
}
