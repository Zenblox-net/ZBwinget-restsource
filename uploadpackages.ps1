
$moduleName = 'Microsoft.WinGet.RestSource'
if (-not (Get-Module -Name $moduleName)) {
    Install-Module -Name $moduleName -AllowPrerelease
    Import-Module -Name $moduleName
}

Connect-AzAccount

$manifestPath = '.\example.manifest.yaml'
winget validate $manifestPath

Add-WinGetManifest -SubscriptionName 'Zenme Azure 1' -FunctionName 'func-jpvwinget8' -Path $manifestPath
# =======

# Get-AzFunctionApp | Select-Object Name, ResourceGroupName
 
# $(Get-AzFunctionApp).Where({ $_.Name -eq 'func-jpvwinget3' }) | Select-Object Name, ResourceGroupName

# $FunctionApp = Get-AzFunctionApp -ResourceGroupName 'jpvwinget3-rg' -Name 'func-jpvwinget3'
# $FunctionAppId = $FunctionApp.Id
# $DefaultHostName = $FunctionApp.DefaultHostName
# $FunctionKeyGet = (Invoke-AzResourceAction -ResourceId "$FunctionAppId/functions/ManifestGet" -Action listkeys -Force).default
