﻿<#
.Synopsis
    Waits for Azure PIR to complete replication of VM extension

.Usage
    WaitForExtensionReplication.ps1 -extensionName ReleaseManagement1 -publisher Test.Microsoft.VisualStudio.Services -extensionVersion 1.9.0.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$extensionManifestPath,

    [Parameter(Mandatory=$false)]
    [string]$location
)

[xml]$content = Get-Content $extensionManifestPath
$extensionName = $content.ExtensionImage.Type
$publisher = $content.ExtensionImage.ProviderNameSpace
$extensionVersion = $content.ExtensionImage.Version

$retryCount = 0
$isReplicated = $false

# retry after every 120 seconds
$retryInterval = 120

# maximum number of retries to attempt
$maxRetries = 1440

if (!$location) { $location = "southcentralus" }
$location = $location.Split(';')[-1].Replace(' ', '').ToLower()

do
{
  try 
  {
      $extensionDetails = Get-AzureRmVMExtensionImage -Location $location -PublisherName $publisher -Type $extensionName -Version $extensionVersion -ErrorAction SilentlyContinue
      $isReplicated = $extensionDetails.Version -eq $extensionVersion
  }
  catch 
  {
      $isReplicated = $false
  }
  
  if($isReplicated -ne $true)
  {
    Write-Host "Extension is not yet replicated. Will retry after $retryInterval seconds"
    $retryCount++
    Start-Sleep -s $retryInterval
  }

  Write-Host "is Replicated: $isReplicated, retry count: $retryCount, max retries: $maxRetries"

} While (($isReplicated -ne $true) -and ($retryCount -lt $maxRetries))

if($isReplicated -ne $true)
{
    Write-Error "Extension is not yet replicated. Failing with timeout."
}
