<#
.Synopsis
    Delete older version of extension from PIR. this is required as Azure only suuports 15 extension versions from a partiular subscription.

.Usage
    DeleteOldExtension.ps1 -extensionName ReleaseManagement1 -publisher Test.Microsoft.VisualStudio.Services -versionToDelete 1.9.0.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$extensionName,

    [Parameter(Mandatory=$true)]
    [string]$publisher,
    
    [string]$versionToDelete
)

if($versionToDelete -eq "WILL_BET_SET_AT_RUNTIME")
{
    return
}

Write-Host "Will delete extension version: $versionToDelete"

$subscription = Get-AzureSubscription -Current –ExtendedDetails
$subscription.Certificate.Thumbprint

$uri = "https://management.core.windows.net/$($subscription.SubscriptionId)/services/extensions/$publisher/$extensionName/$versionToDelete"
Write-Host "uri: $uri"

Invoke-RestMethod -Method DELETE -Uri $uri -Certificate $subscription.Certificate -Headers @{'x-ms-version'='2014-08-01'}