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

if($versionToDelete -eq "NOTHING_TO_DELETE")
{
    Write-Host "No extension will be deleted"
    exit 0
}

Write-Host "Deleting extension version: $versionToDelete"
$subscription = Get-AzureSubscription -Current –ExtendedDetails
$subscription.Certificate.Thumbprint

# First set extension as internal and then delete
[xml]$definitionXml = [xml]('<?xml version="1.0" encoding="utf-8"?>
  <ExtensionImage xmlns="http://schemas.microsoft.com/windowsazure" xmlns:i="http://www.w3.org/2001/XMLSchema-instance">   
  <ProviderNameSpace></ProviderNameSpace>
  <Type></Type>
  <Version></Version>
  <IsInternalExtension>true</IsInternalExtension>
  <IsJsonExtension>true</IsJsonExtension>
  </ExtensionImage>')

$definitionXml.ExtensionImage.ProviderNameSpace = [string]$publisher
$definitionXml.ExtensionImage.Type = [string]$extensionName
$definitionXml.ExtensionImage.Version = [string]$versionToDelete
$($definitionXml.ExtensionImage.version)

$putUri = "https://management.core.windows.net/$($subscription.SubscriptionId)/services/extensions?action=update"
Write-Host "Updating extension to mark it as internal. using uri: $putUri"
try {
    Invoke-RestMethod -Method PUT -Uri $putUri -Certificate $subscription.Certificate -Headers @{'x-ms-version'='2014-08-01'} -Body $definitionXml -ContentType application/xml
}
catch {
    Write-Host $Error[0]
    throw
}

Start-Sleep -Seconds 10

# now delete
$uri = "https://management.core.windows.net/$($subscription.SubscriptionId)/services/extensions/$publisher/$extensionName/$versionToDelete"
Write-Host "Deleting extension. using uri: $uri"

Invoke-RestMethod -Method DELETE -Uri $uri -Certificate $subscription.Certificate -Headers @{'x-ms-version'='2014-08-01'}