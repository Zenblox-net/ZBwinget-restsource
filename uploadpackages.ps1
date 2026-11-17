
$moduleName = 'Microsoft.WinGet.RestSource'
if (-not (Get-Module -Name $moduleName)) {
    Install-Module -Name $moduleName -AllowPrerelease
    Import-Module -Name $moduleName
}

Connect-AzAccount

$manifestPath = '.\example.manifest.yaml'
winget validate $manifestPath

Add-WinGetManifest -SubscriptionName 'Zenme Azure 1' -FunctionName 'func-jpvwinget9' -Path $manifestPath
# =======
# Usage
# =======

winget source add --name 'ZenmePrivate' --arg 'https://apim-jpvwinget9.azure-api.net/winget' --type 'Microsoft.Rest'

winget search 7zip --source ZenmePrivate

winget install --id '7zip.7zip' --exact --source ZenmePrivate
