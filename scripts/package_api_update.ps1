# Produces API program files only. Never bundle an installer, database, settings or secrets.
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$DotnetPath,
    [Parameter(Mandatory=$true)][string]$OutputDirectory,
    [Parameter(Mandatory=$true)][ValidatePattern('^[a-f0-9]{40}$')][string]$SourceCommit,
    [ValidatePattern('^0\.1\.0-dev\.[0-9]+$')][string]$Version = '0.1.0-dev.27'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repo = Split-Path $PSScriptRoot -Parent
$output = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $output) { throw 'Output directory must be new.' }
$null = New-Item -ItemType Directory -Path $output
$api = Join-Path $output 'api'
& $DotnetPath publish (Join-Path $repo 'services\api\Budgetism.Api.csproj') --configuration Release --runtime win-x64 --self-contained true --output $api --source https://api.nuget.org/v3/index.json -p:PublishSingleFile=false -p:IsTransformWebConfigDisabled=true -p:DebugType=None -p:DebugSymbols=false "-p:SourceRevisionId=$SourceCommit" "-p:Version=$Version"
if ($LASTEXITCODE -ne 0) { throw 'API publish failed.' }
$contract = [ordered]@{format=1;appId='budgetism-api';version=$Version;sourceCommit=$SourceCommit;runtime='win-x64';apiMajor=1;clientApiContract=1;bankSchema=1;planningSchema=1;updateContract=1;requiresMigration=$false}
$utf8 = New-Object Text.UTF8Encoding $false
[IO.File]::WriteAllText((Join-Path $api 'api-update-contract.json'),($contract | ConvertTo-Json -Depth 5),$utf8)
$files = @(Get-ChildItem -LiteralPath $api -Recurse -File | Sort-Object FullName | ForEach-Object {
    if (($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Reparse point in API package.' }
    $name = $_.FullName.Substring($api.Length+1).Replace('\','/')
    if ($name -match '^(?i:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|$)' -or $name.EndsWith('.') -or $name.EndsWith(' ')) { throw 'Reserved Windows API package member.' }
    # Flat self-contained .NET deployment; do not silently permit newly introduced file kinds.
    if ($name.Contains('/') -or ($name -notmatch '^[A-Za-z0-9_.+-]+\.dll$' -and $name -notin @('Budgetism.Api.exe','Budgetism.Api.deps.json','Budgetism.Api.runtimeconfig.json','api-update-contract.json'))) {
        throw "Unsupported API-only package member: $name"
    }
    [ordered]@{path='api/'+$name;sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant();size=$_.Length}
})
if (@($files | Where-Object path -eq 'api/Budgetism.Api.exe').Count -ne 1) { throw 'API executable missing.' }
$manifest = [ordered]@{}
foreach ($key in $contract.Keys) { $manifest[$key] = $contract[$key] }
$manifest.files = $files
[IO.File]::WriteAllText((Join-Path $output 'update-manifest.json'),($manifest | ConvertTo-Json -Depth 6),$utf8)
Write-Output 'API-only program package staged; no installation, migration or publication performed.'
