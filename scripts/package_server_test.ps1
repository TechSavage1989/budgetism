[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$DotnetPath,
    [Parameter(Mandatory=$true)][string]$PostgresDirectory,
    [Parameter(Mandatory=$true)][string]$OutputDirectory
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$output = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $output) { throw 'Output directory must be new.' }
foreach ($name in @('bin\postgres.exe','bin\pg_ctl.exe','bin\initdb.exe','share\postgresql.conf.sample')) {
    if (-not (Test-Path -LiteralPath (Join-Path $PostgresDirectory $name))) { throw "Missing PostgreSQL component: $name" }
}
$null = New-Item -ItemType Directory -Path $output
& $DotnetPath publish (Join-Path $repo 'services\api\Budgetism.Api.csproj') --configuration Release --runtime win-x64 --self-contained true --output (Join-Path $output 'api') --source https://api.nuget.org/v3/index.json -p:PublishSingleFile=false -p:DebugType=None -p:DebugSymbols=false
if ($LASTEXITCODE -ne 0) { throw 'API publish failed.' }
$null = New-Item -ItemType Directory -Path (Join-Path $output 'postgresql')
foreach ($directory in @('bin','lib','share')) {
    Copy-Item -LiteralPath (Join-Path $PostgresDirectory $directory) -Destination (Join-Path $output 'postgresql') -Recurse
}
foreach ($license in @('server_license.txt','commandlinetools_3rd_party_licenses.txt')) {
    Copy-Item -LiteralPath (Join-Path $PostgresDirectory $license) -Destination (Join-Path $output 'postgresql')
}
Copy-Item -LiteralPath (Join-Path $repo 'scripts\test_private_server.ps1') -Destination (Join-Path $output 'Test-BudgetismServer.ps1')
Copy-Item -LiteralPath (Join-Path $repo 'scripts\install_private_server.ps1') -Destination (Join-Path $output 'Install-BudgetismServer.ps1')
Copy-Item -LiteralPath (Join-Path $repo 'scripts\upgrade_bank_sources_v1.sql') -Destination (Join-Path $output 'Upgrade-BudgetismBankSources.sql')
Copy-Item -LiteralPath (Join-Path $repo 'scripts\upgrade_planning_v1.sql') -Destination (Join-Path $output 'Upgrade-BudgetismPlanning.sql')
Copy-Item -LiteralPath (Join-Path $repo 'docs\WINDOWS_SERVER_SETUP.md') -Destination (Join-Path $output 'README.md')
$files = @(Get-ChildItem -LiteralPath $output -Recurse -File | Sort-Object FullName | ForEach-Object {
    [ordered]@{ path=$_.FullName.Substring($output.Length+1).Replace('\','/'); sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant() }
})
[ordered]@{format=1;purpose='Fictional Windows server smoke test; not a Plaid release';files=$files} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $output 'manifest.json') -Encoding UTF8
Write-Output "Server test package staged at $output"
