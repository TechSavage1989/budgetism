param(
    [Parameter(Mandatory=$true)][string]$Version,
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)
$ErrorActionPreference = 'Stop'
$release = Join-Path $ProjectRoot 'apps/client/build/windows/x64/runner/Release'
if (-not (Test-Path $release -PathType Container)) {
    $release = Join-Path $ProjectRoot 'apps/client/build/windows/runner/Release'
}
if (-not (Test-Path $release -PathType Container)) {
    throw 'Flutter Windows release build not found. Compile the app first.'
}
$builtExe = Join-Path $release 'budgetism.exe'
if (-not (Test-Path $builtExe -PathType Leaf)) { throw 'Expected Flutter executable budgetism.exe not found.' }
$updater = Join-Path $ProjectRoot 'build/tools/Budgetism-Updater.exe'
if (-not (Test-Path $updater -PathType Leaf)) { throw 'Expected independently built Windows updater missing.' }
$packages = Join-Path $ProjectRoot 'build/packages'
New-Item $packages -ItemType Directory -Force | Out-Null
$temp = Join-Path $packages 'staging'
if (Test-Path $temp) { Remove-Item $temp -Recurse -Force }
$folder = Join-Path $temp 'Budgetism'
New-Item $folder -ItemType Directory -Force | Out-Null
Copy-Item (Join-Path $release '*') $folder -Recurse -Force
Rename-Item (Join-Path $folder 'budgetism.exe') 'Budgetism.exe'
Copy-Item $updater (Join-Path $folder 'Budgetism-Updater.exe')
$identity = [ordered]@{
  appId = 'TechSavage1989.Budgetism'
  version = $Version
  platform = 'windows-x64'
  executable = 'Budgetism.exe'
}
$identity | ConvertTo-Json -Depth 3 | Set-Content (Join-Path $folder 'app-release.json') -Encoding utf8
$archive = Join-Path $packages 'Budgetism-Windows-x64.zip'
if (Test-Path $archive) { Remove-Item $archive -Force }
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($temp, $archive, [System.IO.Compression.CompressionLevel]::Optimal, $false)
$hash = (Get-FileHash -Path $archive -Algorithm SHA256).Hash.ToLowerInvariant()
"$hash  Budgetism-Windows-x64.zip" | Set-Content (Join-Path $packages 'checksums.sha256') -Encoding ascii
Remove-Item $temp -Recurse -Force
Write-Host "Package created: $archive"
Write-Host "SHA-256: $hash"
Write-Host 'No GitHub release has been published by this script.'
