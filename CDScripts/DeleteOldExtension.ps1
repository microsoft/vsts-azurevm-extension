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

if(($versionToDelete -eq "WILL_BET_SET_AT_RUNTIME") -or ($versionToDelete -eq "") -or ($versionToDelete -eq $null))
{
    # Fetching list of published extension handler. Using South Central US location. Since, we are insterested in oldest version, it does not matter which location we use as replication would have anyways completed.
    $extensions = Get-AzureRmVMExtensionImage -Location southcentralus -PublisherName $publisher -Type $extensionName

    Write-Host "Published extension handler versions:"
    $extensions | % { Write-Host $_.version}

    if($extensions.Count -ge 5) 
    {
        $versionToDelete = $extensions[0].Version
        Write-Host "5 or more extension handler versions are published. Oldest version will be deleted"
    }
    else
    {
        Write-Host "Less than 5 handler version published currently. None will be deleted"
        exit 0
    }
}

Write-Host "Deleting extension version: $versionToDelete"

$subscription = Get-AzureSubscription -Current –ExtendedDetails
$subscription.Certificate.Thumbprint

$uri = "https://management.core.windows.net/$($subscription.SubscriptionId)/services/extensions/$publisher/$extensionName/$versionToDelete"
Write-Host "uri: $uri"

Invoke-RestMethod -Method DELETE -Uri $uri -Certificate $subscription.Certificate -Headers @{'x-ms-version'='2014-08-01'}