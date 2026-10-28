param(
    [Parameter(Mandatory=$true)][string]$Archive,
    [Parameter(Mandatory=$true)][string]$ReportDirectory
)
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
New-Item -ItemType Directory -Force $ReportDirectory | Out-Null
$archivePath = (Resolve-Path -LiteralPath $Archive).Path
$reportPath = Join-Path $ReportDirectory 'defender-scan.json'
$report = [ordered]@{
    status = 'incomplete'
    scanUtc = (Get-Date).ToUniversalTime().ToString('o')
    archiveSha256 = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
    engine = $null
    signatures = $null
    signatureUpdated = $null
    scans = @()
    limitations = 'One Microsoft Defender scan at build time. Not publisher signing, independent security review, or clearance by every browser/antivirus.'
}
try {
    $status = Get-MpComputerStatus -ErrorAction Stop
    if (-not $status.AMServiceEnabled -or -not $status.AntivirusEnabled) {
        throw 'Microsoft Defender is not active on this runner. No malware-clearance claim is possible.'
    }
    Update-MpSignature -ErrorAction Stop
    $status = Get-MpComputerStatus -ErrorAction Stop
    $report.engine = $status.AMEngineVersion
    $report.signatures = $status.AntivirusSignatureVersion
    $report.signatureUpdated = $status.AntivirusSignatureLastUpdated.ToUniversalTime().ToString('o')
    if ($status.AntivirusSignatureLastUpdated -lt (Get-Date).AddDays(-7)) {
        throw 'Defender security intelligence is too old for this package check.'
    }
    $platform = Join-Path $env:ProgramData 'Microsoft\Windows Defender\Platform'
    $exe = Get-ChildItem -LiteralPath $platform -Directory -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending | ForEach-Object { Join-Path $_.FullName 'MpCmdRun.exe' } |
        Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if (-not $exe) { $exe = Join-Path $env:ProgramFiles 'Windows Defender\MpCmdRun.exe' }
    if (-not (Test-Path -LiteralPath $exe)) { throw 'Defender command-line scanner was not found.' }
    $expanded = Join-Path $ReportDirectory 'scan-content'
    if (Test-Path -LiteralPath $expanded) { throw 'Refusing to reuse a scan extraction directory.' }
    Expand-Archive -LiteralPath $archivePath -DestinationPath $expanded
    $filesBefore = @(Get-ChildItem -LiteralPath $expanded -File -Recurse | Sort-Object FullName |
        ForEach-Object { "$($_.FullName)=$((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash)" })
    foreach ($target in @($archivePath, (Resolve-Path -LiteralPath $expanded).Path)) {
        # No global security setting or exclusion is changed. For this custom
        # scan, DisableRemediation ignores file exclusions and reports detections
        # without altering the evidence. Any detection/error blocks delivery.
        $output = @(& $exe -Scan -ScanType 3 -File $target -DisableRemediation 2>&1 | ForEach-Object { "$_" })
        $exitCode = $LASTEXITCODE
        $logName = if ($target -eq $archivePath) { 'archive-scan.txt' } else { 'expanded-scan.txt' }
        $output | Set-Content -LiteralPath (Join-Path $ReportDirectory $logName) -Encoding utf8
        $report.scans += [ordered]@{ target = $logName; exitCode = $exitCode; output = $output }
        $text = $output -join [Environment]::NewLine
        if ($exitCode -ne 0 -or $text -notmatch '(?i)(scan finished|found no threats|no threats found)' -or
            $text -match '(?i)(Threat\s*:\s*\S|Threat\s+(ID|Name|Detected)\s*[:=]|Found\s+[1-9][0-9]*\s+threats)') {
            throw "Defender did not return an explicit clean result. Inspect $logName."
        }
    }
    $filesAfter = @(Get-ChildItem -LiteralPath $expanded -File -Recurse | Sort-Object FullName |
        ForEach-Object { "$($_.FullName)=$((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash)" })
    if (Compare-Object $filesBefore $filesAfter) { throw 'Extracted package bytes changed during scanning.' }
    if ((Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $report.archiveSha256) {
        throw 'The package changed during validation.'
    }
    $report.status = 'no-threats-detected'
    Remove-Item -LiteralPath $expanded -Recurse -Force
} catch {
    $report.status = 'blocked-or-unavailable'
    $report.error = $_.Exception.Message
    throw
} finally {
    $report | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $reportPath -Encoding utf8
}
Write-Host 'Microsoft Defender reported no threats for the archive and its extracted contents.'
