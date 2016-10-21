<#
.Synopsis
    Creates a new Azure VM extension. It triggers REST API and does not wait for extension replication.
    Uses extension's definition xml file to obtain current version.

.Usage
    CreateVMExtension.ps1 -relativeExtensionDefinitionPath "VM extension\ExtensionDefinition_Test.xml"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$relativeExtensionDefinitionPath
)

$artifactsDir = Join-Path $env:SYSTEM_ARTIFACTSDIRECTORY $env:BUILD_DEFINITIONNAME
$definitionFile = Join-Path $artifactsDir $relativeExtensionDefinitionPath

# read extension definition
$bodyxml = Get-Content $definitionFile
Write-Host "Body xml: $bodyxml"

# fetch subscription details - subscription id and management certificate
$subscription = Get-AzureSubscription -Current -ExtendedDetails
$subscription.Certificate.Thumbprint

$uri = "https://management.core.windows.net/$($subscription.SubscriptionId)/services/extensions"
Write-Host "uri: $uri"

$xml = [xml]$bodyxml
Write-Host "Updating extension to version: $($xml.ExtensionImage.Version)"

# invoke PUT rest api to update the extension
Invoke-RestMethod -Method POST -Uri $uri -Certificate $subscription.Certificate -Headers @{'x-ms-version'='2014-08-01'} -Body $bodyxml -ContentType application/xml

# set this version as value for release variable 
[xml]$xml = $bodyxml
$newVersion = $xml.ExtensionImage.Version
$newVersionVariable = "NewVersion"
Write-Host "##vso[task.setvariable variable=$newVersionVariable;]$newVersion"