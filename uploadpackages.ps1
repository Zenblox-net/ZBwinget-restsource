
Install-Module -Name Microsoft.WinGet.RestSource -AllowPrerelease

Connect-AzAccount

Import-Module Microsoft.WinGet.RestSource

$manifestPath = '.\example.manifest.yaml'
winget validate $manifestPath

Add-WinGetManifest -SubscriptionName 'Zenme Azure 1' -FunctionName 'func-jpvwinget3' -Path $manifestPath
# =======

# Get-AzFunctionApp | Select-Object Name, ResourceGroupName
 
# $(Get-AzFunctionApp).Where({ $_.Name -eq 'func-jpvwinget3' }) | Select-Object Name, ResourceGroupName

# $FunctionApp = Get-AzFunctionApp -ResourceGroupName 'jpvwinget3-rg' -Name 'func-jpvwinget3'
# $FunctionAppId = $FunctionApp.Id
# $DefaultHostName = $FunctionApp.DefaultHostName
# $FunctionKeyGet = (Invoke-AzResourceAction -ResourceId "$FunctionAppId/functions/ManifestGet" -Action listkeys -Force).default
