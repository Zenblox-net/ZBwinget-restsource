#Requires -Version 7.4

$ErrorActionPreference = 'Stop'
$settings = Import-PowerShellDataFile (Join-Path $PSScriptRoot 'deploy-settings.psd1')

foreach ($moduleName in @('Az')) {
    if (-not (Get-Module -ListAvailable -Name $moduleName)) {
        Install-Module -Name $moduleName -Scope CurrentUser -AllowClobber
    }
}

Import-Module Az.Accounts
& (Join-Path $PSScriptRoot 'Tools/PowershellModule/build-local-module.ps1')
Import-Module (Join-Path $PSScriptRoot 'artifacts/Microsoft.WinGet.RestSource/Microsoft.WinGet.RestSource.psd1') -Force

try {
    $context = Set-AzContext -Tenant $settings.TenantId -SubscriptionId $settings.SubscriptionId -ErrorAction Stop
} catch {
    Connect-AzAccount -Tenant $settings.TenantId -Subscription $settings.SubscriptionId | Out-Null
    $context = Set-AzContext -Tenant $settings.TenantId -SubscriptionId $settings.SubscriptionId
}
if ($context.Tenant.Id -ne $settings.TenantId -or $context.Subscription.Id -ne $settings.SubscriptionId) {
    throw 'The Azure context does not match deploy-settings.psd1.'
}
& az account set --subscription $settings.SubscriptionId --only-show-errors
if ($LASTEXITCODE -ne 0) {
    throw 'Azure CLI is not authenticated to the subscription in deploy-settings.psd1. Run az login for the configured tenant and retry.'
}

$sourceSettings = $settings.Clone()
$sourceSettings.Remove('TenantId')
$sourceSettings.Remove('SubscriptionId')
$resourceGroupName = $settings.Name -replace '[^a-zA-Z0-9-]', ''
$sourceSettings['ResourceGroup'] = "$resourceGroupName-rg"

foreach ($pathSetting in @('TemplateFolderPath', 'ParameterOutputPath', 'RestSourcePath')) {
    if ([string]::IsNullOrWhiteSpace($sourceSettings[$pathSetting])) {
        $sourceSettings.Remove($pathSetting)
    } else {
        $sourceSettings[$pathSetting] = [System.IO.Path]::GetFullPath($sourceSettings[$pathSetting], $PSScriptRoot)
    }
}

$result = New-WinGetSource @sourceSettings
if (-not $result) {
    throw 'WinGet REST source deployment failed.'
}