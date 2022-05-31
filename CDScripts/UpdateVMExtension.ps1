<#
.Synopsis
    Pushes a new version of extension to Azure PIR. 
    Uses extension's definition xml file to obtain current version.

.Usage
    UpdateVMExtension.ps1 -relativeExtensionDefinitionPath "VM extension\ExtensionDefinition_Test_MIGRATED.xml"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$relativeExtensionDefinitionPath
)

$definitionFile = $relativeExtensionDefinitionPath

if($env:SYSTEM_ARTIFACTSDIRECTORY -and $env:BUILD_DEFINITIONNAME)
{
    $artifactsDir = Join-Path $env:SYSTEM_ARTIFACTSDIRECTORY $env:BUILD_DEFINITIONNAME
    $definitionFile = Join-Path $artifactsDir $relativeExtensionDefinitionPath
}

# read extension definition
$bodyxml = Get-Content $definitionFile
Write-Host "Body xml: $bodyxml"

# fetch subscription details - subscription id and management certificate
$subscription = Get-AzureSubscription -Current -ExtendedDetails
$subscription.Certificate.Thumbprint

$uri = "https://management.core.windows.net/$($subscription.SubscriptionId)/services/extensions?action=update"
Write-Host "uri: $uri"

$xml = [xml]$bodyxml
Write-Host "Updating extension to version: $($xml.ExtensionImage.Version)"

# invoke PUT rest api to update the extension
#Invoke-RestMethod -Method PUT -Uri $uri -Certificate $subscription.Certificate -Headers @{'x-ms-version'='2014-08-01'} -Body $bodyxml -ContentType application/xml

$retryCount = 0
$isUpdateQueued = $false

# retry after every 120 seconds
$retryInterval = 120

# maximum number of retries to attempt
$maxRetries = 60

do
{
  try 
  {
      Invoke-RestMethod -Method PUT -Uri $uri -Certificate $subscription.Certificate -Headers @{'x-ms-version'='2014-08-01'} -Body $bodyxml -ContentType application/xml -ErrorAction SilentlyContinue
      $isUpdateQueued = $true
  }
  catch
  {
      $isUpdateQueued = $false
      Write-Host "Exception code: $($error[0].Exception.Response.StatusCode.ToString())"

      if($error[0].Exception.Response.StatusCode.ToString() -ne "Conflict")
      {
          Write-Error "Failed with non-conflict error. No need to retry. Fail now."
          exit
      }
  }
  
  if($isUpdateQueued -ne $true)
  {
    Write-Host "Extension update not queued. Will retry after $retryInterval seconds"
    $retryCount++
    Start-Sleep -s $retryInterval
  }

  Write-Host "is queued: $isUpdateQueued, retry count: $retryCount, max retries: $maxRetries"


} While (($isUpdateQueued -ne $true) -and ($retryCount -lt $maxRetries))

if($isUpdateQueued -ne $true)
{
    Write-Error "Could not queue extension update. Failing with timeout."
}

# set this version as value for release variable 
[xml]$xml = $bodyxml
$newVersion = $xml.ExtensionImage.Version
$newVersionVariable = "NewVersion"
Write-Host "##vso[task.setvariable variable=$newVersionVariable;]$newVersion"