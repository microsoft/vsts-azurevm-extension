<#
.Synopsis
    Delete older version of extension from PIR. this is required as Azure only suuports 15 extension versions from a partiular subscription.
#>

param(
    [string]$versionToDelete
)

if([string]::IsNullOrEmpty($versionToDelete))
{
    return
}

$versionToDelete

$subscription = Get-AzureSubscription -Current –ExtendedDetails
$subscription.Certificate.Thumbprint

$uri = "https://management.core.windows.net/$($subscription.SubscriptionId)/services/extensions/Test.Microsoft.VisualStudio.Services/ReleaseManagement1/$versionToDelete"
$uri
Invoke-RestMethod -Method DELETE -Uri $uri -Certificate $subscription.Certificate -Headers @{'x-ms-version'='2014-08-01'}