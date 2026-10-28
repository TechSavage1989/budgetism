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
    Update-MpSignature -ErrorAction Stop
    $status = Get-MpComputerStatus -ErrorAction Stop
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
