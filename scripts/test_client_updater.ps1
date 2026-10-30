param(
  [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [string]$PackageArchive = (Join-Path $ProjectRoot 'build/packages/Budgetism-Windows-x64.zip')
)
$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'Native updater acceptance requires Windows PowerShell Core.' }
Add-Type -AssemblyName System.IO.Compression.FileSystem
$PackageArchive = (Resolve-Path $PackageArchive).Path
$originalHash = (Get-FileHash $PackageArchive -Algorithm SHA256).Hash
$root = Join-Path ([IO.Path]::GetTempPath()) ('budgetism-native-update-' + [guid]::NewGuid().ToString('N'))
New-Item $root -ItemType Directory | Out-Null
$evidence = Join-Path $ProjectRoot 'build/updater-native'
New-Item $evidence -ItemType Directory -Force | Out-Null
$results = [Collections.Generic.List[object]]::new()
$ownedAttempts=[Collections.Generic.List[string]]::new()
$ownedIdentities=[Collections.Generic.List[string]]::new()
$supportPath=$null
function Assert([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Wait-For([scriptblock]$Condition, [int]$Seconds = 90) {
  $until = [DateTime]::UtcNow.AddSeconds($Seconds)
  do { if (& $Condition) { return }; Start-Sleep -Milliseconds 200 } while ([DateTime]::UtcNow -lt $until)
  throw 'Native update condition timed out.'
}
function Stop-Owned([string]$Folder) {
  Get-CimInstance Win32_Process | Where-Object { $_.ExecutablePath -and [IO.Path]::GetDirectoryName($_.ExecutablePath) -eq $Folder } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
  Start-Sleep -Milliseconds 300
}
function Seed([string]$Archive) {
  $env:BUDGETISM_TEST_UPDATE_ARCHIVE=$Archive
  $env:BUDGETISM_TEST_UPDATE_VERSION='0.1.0-dev.28'
  $env:BUDGETISM_TEST_UPDATE_SHA=(Get-FileHash $Archive -Algorithm SHA256).Hash.ToLowerInvariant()
  $env:BUDGETISM_TEST_UPDATE_SUPPORT_FILE=Join-Path $root 'support.txt'
  Push-Location (Join-Path $ProjectRoot 'apps/client')
  try { & flutter test integration_test/update_fixture_seed_test.dart -d windows --dart-define=APP_VERSION=0.1.0-dev.27 | Out-Host; if ($LASTEXITCODE -ne 0) { throw 'Native fixture seed failed.' } } finally { Pop-Location }
  $script:supportPath=(Get-Content $env:BUDGETISM_TEST_UPDATE_SUPPORT_FILE -Raw).Trim()
  $script:ownedIdentities.Add('0.1.0-dev.28-'+$env:BUDGETISM_TEST_UPDATE_SHA)
  return $script:supportPath
}
function Install-Case([string]$Name,[string]$Archive,[string]$LaunchName='Budgetism.exe',[bool]$BlockOther=$false,[bool]$ExpectSuccess=$true) {
  $case=Join-Path $root $Name;New-Item $case -ItemType Directory|Out-Null
  [IO.Compression.ZipFile]::ExtractToDirectory($PackageArchive,$case)
  $target=Join-Path $case 'Budgetism';$exe=Join-Path $target $LaunchName
  if($LaunchName -ne 'Budgetism.exe'){Rename-Item (Join-Path $target 'Budgetism.exe') $LaunchName}
  $oldHash=(Get-FileHash $exe -Algorithm SHA256).Hash
  $blocker=$null;$attempt=$null
  try {
    if($BlockOther){$env:BUDGETISM_UPDATE_SKIP_ONCE='1';$blocker=Start-Process $exe -PassThru;Remove-Item Env:BUDGETISM_UPDATE_SKIP_ONCE;Start-Sleep -Seconds 3}
    $support=Seed $Archive
    $sentinel=Join-Path $support ('fixture-preservation-'+$Name+'.txt');[IO.File]::WriteAllText($sentinel,'fictional settings outside installation')
    $attemptRoot=Join-Path $support 'updates/attempts';$before=@();if(Test-Path $attemptRoot){$before=@(Get-ChildItem $attemptRoot -Directory|ForEach-Object Name)}
    $launch=Start-Process $exe -PassThru
    Wait-For { (Test-Path $attemptRoot) -and @(Get-ChildItem $attemptRoot -Directory | Where-Object Name -NotIn $before).Count -gt 0 }
    $attempt=@(Get-ChildItem $attemptRoot -Directory | Where-Object Name -NotIn $before)[0].FullName
    $script:ownedAttempts.Add($attempt)
    Wait-For { Test-Path (Join-Path $attempt 'result.json') } 100
    $receipt=Get-Content (Join-Path $attempt 'result.json') -Raw|ConvertFrom-Json
    if($ExpectSuccess){
      Assert ($receipt.status -eq 'installed') 'Expected genuine application update success.'
      $ready=Get-Content (Join-Path $attempt 'ready.json') -Raw|ConvertFrom-Json
      Assert ($ready.version -eq '0.1.0-dev.28') 'New application did not acknowledge fixture version.'
      Assert ((Get-Content (Join-Path $target 'app-release.json') -Raw|ConvertFrom-Json).version -eq '0.1.0-dev.28') 'Installed marker mismatch.'
      $backup=Join-Path $case '.Budgetism.previous'
      Assert ((Get-FileHash (Join-Path $backup $LaunchName) -Algorithm SHA256).Hash -eq $oldHash) 'Persistent rollback copy differs from original.'
      Assert ((Get-Process -Id $ready.pid -ErrorAction SilentlyContinue) -ne $null) 'New application is not running.'
      $launch.Refresh();Assert $launch.HasExited 'Startup bootstrap did not exit before installation.'
    } else {
      Assert ($receipt.status -in @('failed','rolledBack')) 'Negative fixture was incorrectly installed.'
      if(-not $BlockOther){Assert ($receipt.status -eq 'rolledBack') 'Rollback readiness was not verified.';$restored=Get-Content (Join-Path $attempt 'ready.json') -Raw|ConvertFrom-Json;Assert ($restored.version -eq '0.1.0-dev.27') 'Rollback version mismatch.';Assert ((Get-Process -Id $restored.pid -ErrorAction SilentlyContinue) -ne $null) 'Restored app is not running.'}
      Assert ((Get-FileHash $exe -Algorithm SHA256).Hash -eq $oldHash) 'Old application was not preserved/restored.'
      if($BlockOther){$blocker.Refresh();Assert (-not $blocker.HasExited) 'Existing session was interrupted.';Assert (-not(Test-Path (Join-Path $attempt 'admitted.json'))) 'Another-instance refusal happened too late.'}
    }
    Assert ((Get-Content $sentinel -Raw) -eq 'fictional settings outside installation') 'User settings sentinel changed.'
    Assert (-not(Test-Path (Join-Path $support 'updates/pending.json'))) 'Pending update was not consumed exactly once.'
    $results.Add([ordered]@{case=$Name;status='passed';result=$receipt.status;version=$receipt.version})
    Copy-Item (Join-Path $attempt 'result.json') (Join-Path $evidence ($Name+'-result.json'))
    Remove-Item $sentinel
  } finally {
    if($attempt){
      if(-not(Test-Path (Join-Path $attempt 'result.json'))){[IO.File]::WriteAllText((Join-Path $attempt 'cancel.json'),'{}')}
      $ownedHelper=Join-Path $attempt 'Budgetism-Updater.exe'
      Wait-For { @(Get-CimInstance Win32_Process | Where-Object ExecutablePath -EQ $ownedHelper).Count -eq 0 } 120
    }
    Stop-Owned $target; Remove-Item Env:BUDGETISM_UPDATE_SKIP_ONCE -ErrorAction SilentlyContinue
  }
}
try {
  Push-Location (Join-Path $ProjectRoot 'tools/updater')
  try { & go test ./...; if($LASTEXITCODE -ne 0){throw 'Native Go updater tests failed.'} } finally {Pop-Location}
  # The next version is a genuine Flutter release build from this exact source,
  # distinguished only by explicit fixture version metadata. It is never published.
  $fixture=Join-Path $root 'future-source';New-Item (Join-Path $fixture 'apps') -ItemType Directory -Force|Out-Null
  & robocopy (Join-Path $ProjectRoot 'apps/client') (Join-Path $fixture 'apps/client') /E /XD build .dart_tool .git /NFL /NDL /NJH /NJS
  if($LASTEXITCODE -gt 7){throw 'Fixture source copy failed.'}
  New-Item (Join-Path $fixture 'build/tools') -ItemType Directory -Force|Out-Null
  Copy-Item (Join-Path $ProjectRoot 'build/tools/Budgetism-Updater.exe') (Join-Path $fixture 'build/tools/Budgetism-Updater.exe')
  Push-Location (Join-Path $fixture 'apps/client')
  try { & flutter pub get;if($LASTEXITCODE -ne 0){throw 'Fixture dependencies failed.'}; & flutter build windows --release --build-name=0.1.0-dev.28 --build-number=28 --dart-define=APP_VERSION=0.1.0-dev.28;if($LASTEXITCODE -ne 0){throw 'Genuine future fixture build failed.'} } finally {Pop-Location}
  & (Join-Path $ProjectRoot 'scripts/package_windows.ps1') -ProjectRoot $fixture -Version '0.1.0-dev.28'
  $future=Join-Path $fixture 'build/packages/Budgetism-Windows-x64.zip'
  & python (Join-Path $ProjectRoot 'scripts/verify_windows_package.py') $future --version 0.1.0-dev.28
  if($LASTEXITCODE -ne 0){throw 'Future package verification failed.'}
  Install-Case 'genuine-startup-success' $future
  Install-Case 'stable-custom-name' $future 'MyBudget.exe'
  Install-Case 'another-session-refused' $future 'Budgetism.exe' $true $false
  # Valid archive/hash/manifest, but actual executable reports the OLD version:
  # a visible window cannot satisfy the new-app version/nonce handshake.
  $wrong=Join-Path $root 'wrong-version';[IO.Compression.ZipFile]::ExtractToDirectory($PackageArchive,$wrong)
  $marker=Join-Path $wrong 'Budgetism/app-release.json';$m=Get-Content $marker -Raw|ConvertFrom-Json;$m.version='0.1.0-dev.28';[IO.File]::WriteAllText($marker,($m|ConvertTo-Json),[Text.UTF8Encoding]::new($false))
  $bad=Join-Path $root 'wrong-version.zip';[IO.Compression.ZipFile]::CreateFromDirectory($wrong,$bad)
  Install-Case 'wrong-running-version-rollback' $bad 'Budgetism.exe' $false $false
  # Corrupt content must fail before installation or launching a package executable.
  $corrupt=Join-Path $root 'corrupt.zip';Copy-Item $future $corrupt;[IO.File]::AppendAllText($corrupt,'corrupt')
  $digest=(Get-FileHash $future -Algorithm SHA256).Hash.ToLowerInvariant()
  & (Join-Path $ProjectRoot 'build/tools/Budgetism-Updater.exe') --archive $corrupt --sha256 $digest --version 0.1.0-dev.28 --verify-only --require-update-protocol 1 --require-client-api-contract 1
  Assert ($LASTEXITCODE -ne 0) 'Corrupt archive was accepted.'
  $results.Add([ordered]@{case='corrupt-package-refused';status='passed'})
  Assert ((Get-FileHash $PackageArchive -Algorithm SHA256).Hash -eq $originalHash) 'Final deliverable archive was changed by fixture tests.'
  [ordered]@{scope='Native fixture dev27 to dev28; not a shipped dev26 bootstrap';results=$results;finalArchiveUnchanged=$true}|ConvertTo-Json -Depth 8|Set-Content (Join-Path $evidence 'summary.json') -Encoding utf8
} finally {
  # Never tear down a fixture installation while its admitted helper might swap.
  # On a stuck helper, fail and retain evidence instead of forcing a late apply.
  foreach($attempt in $ownedAttempts){
    $helperPath=Join-Path $attempt 'Budgetism-Updater.exe'
    if(@(Get-CimInstance Win32_Process | Where-Object ExecutablePath -EQ $helperPath).Count -gt 0){
      [IO.File]::WriteAllText((Join-Path $attempt 'cancel.json'),'{}')
      Wait-For { @(Get-CimInstance Win32_Process | Where-Object ExecutablePath -EQ $helperPath).Count -eq 0 } 120
    }
  }
  Get-ChildItem $root -Filter Budgetism -Directory -Recurse -ErrorAction SilentlyContinue | ForEach-Object {Stop-Owned $_.FullName}
  $supportFile=Join-Path $root 'support.txt'
  if(-not $supportPath -and (Test-Path $supportFile)){$supportPath=(Get-Content $supportFile -Raw).Trim()}
  if($supportPath){
    $stateFile=$supportFile+'.preferences.json'
    if(Test-Path $stateFile){foreach($identity in (Get-Content $stateFile -Raw|ConvertFrom-Json).identities){if($identity -match '^0\.1\.0-dev\.28-[a-f0-9]{64}$'){$ownedIdentities.Add($identity)}}}
    $pendingFile=Join-Path $supportPath 'updates/pending.json'
    if(Test-Path $pendingFile){$queued=Get-Content $pendingFile -Raw|ConvertFrom-Json;if(($queued.version+'-'+$queued.sha256) -in $ownedIdentities){Remove-Item -LiteralPath $pendingFile}}

    foreach($attempt in $ownedAttempts){Remove-Item -LiteralPath $attempt -Recurse -Force -ErrorAction SilentlyContinue}
    foreach($identity in ($ownedIdentities|Select-Object -Unique)){
      Remove-Item -LiteralPath (Join-Path $supportPath ('updates/packages/'+$identity)) -Recurse -Force -ErrorAction SilentlyContinue
      Remove-Item -LiteralPath (Join-Path $supportPath ('updates/attempted/'+$identity+'.json')) -Force -ErrorAction SilentlyContinue
    }
    $env:BUDGETISM_TEST_UPDATE_CLEANUP='1'
    Push-Location (Join-Path $ProjectRoot 'apps/client')
    try { & flutter test integration_test/update_fixture_seed_test.dart -d windows --dart-define=APP_VERSION=0.1.0-dev.27 | Out-Host; if($LASTEXITCODE -ne 0){throw 'Could not restore fixture update preference.'} } finally {Pop-Location}
  }
  Get-ChildItem Env:BUDGETISM_TEST_UPDATE_* | Remove-Item
  Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue
}
