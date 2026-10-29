# Read-only inventory. Does not install software, read secrets, or change settings.
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
function Test-CommandAvailable([string]$Name) {
    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}
function Get-BudgetismReadiness {
    $os = Get-CimInstance Win32_OperatingSystem
    $runtimeVersions = @()
    if (Test-CommandAvailable 'dotnet.exe') {
        $runtimeVersions = @(& dotnet.exe --list-runtimes 2>$null |
            Where-Object { $_ -match '^Microsoft\.(NETCore|AspNetCore)\.App ' } |
            ForEach-Object { ($_ -split '\s+')[0..1] -join ' ' })
    }
    $services = @(Get-Service -ErrorAction SilentlyContinue)
    $postgres = @($services | Where-Object { $_.Name -match '^postgresql' } |
        ForEach-Object { [ordered]@{ name = $_.Name; status = [string]$_.Status } })
    $listeners = @(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue)
    $volumes = @(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' |
        ForEach-Object { [ordered]@{
            drive = $_.DeviceID
            freeGiB = [math]::Round($_.FreeSpace / 1GB, 1)
        } })
    [ordered]@{
        reportVersion = 1
        purpose = 'Budgetism read-only server readiness; no credentials collected'
        os = $os.Caption
        osVersion = $os.Version
        architecture = $os.OSArchitecture
        powerShellVersion = [string]$PSVersionTable.PSVersion
        dotnetRuntimes = $runtimeVersions
        postgresServices = $postgres
        iisServicePresent = [bool]($services.Name -contains 'W3SVC')
        dockerCommandPresent = Test-CommandAvailable 'docker.exe'
        relevantListeningPorts = @($listeners.LocalPort |
            Where-Object { $_ -in @(80,443,5432,5080,5443) } | Sort-Object -Unique)
        disks = $volumes
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    Get-BudgetismReadiness | ConvertTo-Json -Depth 5
}
