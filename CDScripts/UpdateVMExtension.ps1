<#
.Synopsis
    Pushes a new version of extension to Azure PIR. 
    Uses extension's definition xml file to obtain current version.
#>

$artifactsDir = Join-Path $env:SYSTEM_ARTIFACTSDIRECTORY $env:BUILD_DEFINITIONNAME
$definitionFile = Join-Path $artifactsDir "VM extension\ExtensionDefinition_Test.xml"

# read extension definition
$bodyxml = Get-Content $definitionFile
$bodyxml

# fetch subscription details - subscription id and management certificate
$subscription = Get-AzureSubscription -Current –ExtendedDetails
$subscription.Certificate.Thumbprint

$uri = "https://management.core.windows.net/$($subscription.SubscriptionId)/services/extensions?action=update"
$uri

# invoke PUT rest api to update the extension
Invoke-RestMethod -Method PUT -Uri $uri -Certificate $subscription.Certificate -Headers @{'x-ms-version'='2014-08-01'} -Body $bodyxml -ContentType application/xml