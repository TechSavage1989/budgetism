param([Parameter(Mandatory=$true)][string]$ReportDirectory)
$ErrorActionPreference = 'Stop'
# This setup is only for an ephemeral GitHub-hosted build machine. It is never
# bundled with the application or invoked on an end user's computer.
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_ENVIRONMENT -ne 'github-hosted') {
    throw 'Defender initialization is restricted to GitHub-hosted CI.'
}
New-Item -ItemType Directory -Force $ReportDirectory | Out-Null
$report = [ordered]@{ status = 'incomplete'; utc = (Get-Date).ToUniversalTime().ToString('o'); actions = @() }
try {
    $service = Get-Service -Name WinDefend -ErrorAction Stop
    $report.serviceBefore = [ordered]@{ status = "$($service.Status)"; startType = "$($service.StartType)" }
    $platform = Join-Path $env:ProgramData 'Microsoft\Windows Defender\Platform'
    $exe = Get-ChildItem -LiteralPath $platform -Directory -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending | ForEach-Object { Join-Path $_.FullName 'MpCmdRun.exe' } |
        Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if (-not $exe) { $exe = Join-Path $env:ProgramFiles 'Windows Defender\MpCmdRun.exe' }
    if (-not (Test-Path -LiteralPath $exe)) { throw 'Microsoft Defender scanner is unavailable.' }
    # Microsoft's documented enable operation, not a protection bypass.
    $output = @(& $exe -WdEnable 2>&1 | ForEach-Object { "$_" })
    $report.actions += [ordered]@{ command = 'MpCmdRun -WdEnable'; exitCode = $LASTEXITCODE; output = $output }
    $service = Get-Service -Name WinDefend
    if ($service.StartType -eq 'Disabled') {
        Set-Service -Name WinDefend -StartupType Automatic -ErrorAction Stop
        $report.actions += 'Set WinDefend startup to Automatic'
    }
    if ($service.Status -ne 'Running') {
        Start-Service -Name WinDefend -ErrorAction Stop
        $report.actions += 'Start WinDefend'
    }
    $status = $null
    for ($attempt = 0; $attempt -lt 6; $attempt++) {
        try {
            $candidate = Get-MpComputerStatus -ErrorAction Stop
            if ($candidate.AMServiceEnabled -and $candidate.AntivirusEnabled) { $status = $candidate; break }
        } catch { $report.lastStatusError = $_.Exception.Message }
        Start-Sleep -Seconds 5
    }
    if ($null -eq $status) { throw 'Defender did not become available. No scan is claimed and delivery remains blocked.' }
    # The hosted service can restart while fetching its first engine/signatures.
    # Use Microsoft's documented command-line update, then re-read service state.
    # A failed or stale update still blocks the job; this does not relax scanning.
    $report.signatureUpdateAttempts = @()
    $updated = $false
    for ($updateAttempt = 1; $updateAttempt -le 4; $updateAttempt++) {
        $entry = [ordered]@{ attempt = $updateAttempt; status = 'incomplete' }
        try {
            $service = Get-Service -Name WinDefend -ErrorAction Stop
            if ($service.Status -ne 'Running') {
                Start-Service -Name WinDefend -ErrorAction Stop
                $service.WaitForStatus('Running', [TimeSpan]::FromSeconds(20))
            }
            # A platform update may replace the prior scanner path.
            $updateExe = Get-ChildItem -LiteralPath $platform -Directory -ErrorAction SilentlyContinue |
                Sort-Object Name -Descending | ForEach-Object { Join-Path $_.FullName 'MpCmdRun.exe' } |
                Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
            if (-not $updateExe) { $updateExe = $exe }
            $entry.command = 'MpCmdRun -SignatureUpdate'
            $entry.output = @(& $updateExe -SignatureUpdate 2>&1 | ForEach-Object { "$_" })
            $entry.exitCode = $LASTEXITCODE
            if ($entry.exitCode -ne 0) { throw "Signature update failed with exit code $($entry.exitCode)." }
            $status = Get-MpComputerStatus -ErrorAction Stop
            if (-not $status.AMServiceEnabled -or -not $status.AntivirusEnabled -or
                -not $status.AntivirusSignatureLastUpdated -or
                $status.AntivirusSignatureLastUpdated -lt (Get-Date).AddDays(-7)) {
                throw 'Defender is not active with current security intelligence.'
            }
            $entry.status = 'updated-and-ready'
            $updated = $true
        } catch {
            $entry.status = 'failed'
            $entry.error = $_.Exception.Message
        }
        $report.signatureUpdateAttempts += $entry
        if ($updated) { break }
        if ($updateAttempt -lt 4) { Start-Sleep -Seconds (10 * $updateAttempt) }
    }
    if (-not $updated) { throw 'Defender signature initialization failed after bounded retries. Delivery remains blocked.' }
    $report.status = 'ready-for-custom-scan'
    $report.engine = $status.AMEngineVersion
    $report.signatures = $status.AntivirusSignatureVersion
    $report.runningMode = $status.AMRunningMode
    Write-Host 'Defender is available for the required package scan. No exclusions or disabled protections were added.'
} catch {
    $report.status = 'unavailable'
    $report.error = $_.Exception.Message
    throw
} finally {
    $report | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $ReportDirectory 'defender-initialization.json') -Encoding utf8
}
