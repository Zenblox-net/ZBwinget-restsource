#Requires -Version 7.4

$ErrorActionPreference = 'Stop'

$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$SolutionPath = Join-Path $RepositoryRoot 'src/WinGet.RestSource.sln'
$FunctionProjectPath = Join-Path $RepositoryRoot 'src/WinGet.RestSource.Functions/WinGet.RestSource.Functions.csproj'
$NuGetConfigPath = Join-Path $RepositoryRoot 'src/NuGet.config'
$ModuleSourcePath = Join-Path $PSScriptRoot 'src'
$ModuleOutputPath = Join-Path $RepositoryRoot 'artifacts/Microsoft.WinGet.RestSource'
$FunctionPublishPath = Join-Path $RepositoryRoot 'artifacts/WinGet.RestSource.Functions'
$SupportBuildPath = Join-Path $RepositoryRoot 'src/WinGet.RestSource.PowershellSupport/bin/Release/net10.0'
$TemplateSourcePath = Join-Path $RepositoryRoot 'src/WinGet.RestSource.Infrastructure/Templates'
$RestorePackagesPath = Join-Path $env:TEMP 'winget-restsource-nuget-only'
$RestoreSources = 'https://api.nuget.org/v3/index.json'
$UserDotNetRoot = Join-Path $HOME '.dotnet'

if (Test-Path (Join-Path $UserDotNetRoot 'dotnet.exe')) {
    $env:DOTNET_ROOT = $UserDotNetRoot
    $env:PATH = "$UserDotNetRoot;$env:PATH"
}

Push-Location $RepositoryRoot
try {
    dotnet restore $SolutionPath --configfile $NuGetConfigPath
    if ($LASTEXITCODE -ne 0) {
        throw 'Failed to restore the WinGet REST source solution.'
    }

    dotnet build $SolutionPath --configuration Release --no-restore --configfile $NuGetConfigPath "-p:RestoreSources=$RestoreSources" "-p:RestorePackagesPath=$RestorePackagesPath"
    if ($LASTEXITCODE -ne 0) {
        throw 'Failed to build the WinGet REST source solution.'
    }
} finally {
    Pop-Location
}

if (Test-Path $ModuleOutputPath) {
    Remove-Item -Path $ModuleOutputPath -Recurse -Force
}
if (Test-Path $FunctionPublishPath) {
    Remove-Item -Path $FunctionPublishPath -Recurse -Force
}

New-Item -ItemType Directory -Path $ModuleOutputPath -Force | Out-Null
Copy-Item -Path (Join-Path $ModuleSourcePath '*') -Destination $ModuleOutputPath -Recurse -Force

$SupportOutputPath = Join-Path $ModuleOutputPath 'Library/WinGet.RestSource.PowershellSupport'
New-Item -ItemType Directory -Path $SupportOutputPath -Force | Out-Null
Copy-Item -Path (Join-Path $SupportBuildPath '*') -Destination $SupportOutputPath -Recurse -Force

$TemplateOutputPath = Join-Path $ModuleOutputPath 'Data/ARMTemplates'
New-Item -ItemType Directory -Path $TemplateOutputPath -Force | Out-Null
Get-ChildItem -Path $TemplateSourcePath -Filter '*.json' -File -Recurse | Copy-Item -Destination $TemplateOutputPath -Force

Push-Location $RepositoryRoot
try {
    dotnet publish $FunctionProjectPath --configuration Release --no-restore --output $FunctionPublishPath "-p:RestoreSources=$RestoreSources" "-p:RestorePackagesPath=$RestorePackagesPath"
    if ($LASTEXITCODE -ne 0) {
        throw 'Failed to publish the WinGet REST source Function app.'
    }
} finally {
    Pop-Location
}

$FunctionZipPath = Join-Path $ModuleOutputPath 'Data/WinGet.RestSource.Functions.zip'
Compress-Archive -Path (Join-Path $FunctionPublishPath '*') -DestinationPath $FunctionZipPath -Force