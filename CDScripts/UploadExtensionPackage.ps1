<#
.Synopsis
    Upload extension zip file to a blob. Creates a SAS token for this blob and then update blob path in extension definition xml file.
    Azure will download this zip from the public blob and will replicate it across its PIR
.Usage
    UploadExtensionPackage.ps1 -relativePackagePath "VM extension\RMExtension.zip" -relativeExtensionDefinitionPath relativeExtensionDefinitionPath -storageResourceGroup rmvmextensiontest -storageAccountName rmvmextensiontest -storageContainerName agentextension -storageBlobName RMExtension.zip
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$relativePackagePath,

    [Parameter(Mandatory=$true)]
    [string]$relativeExtensionDefinitionPath,

    [Parameter(Mandatory=$true)]
    [string]$storageResourceGroup,
    
    [Parameter(Mandatory=$true)]
    [string]$storageAccountName,
    
    [Parameter(Mandatory=$true)]
    [string]$storageContainerName,

    [Parameter(Mandatory=$true)]
    [string]$storageBlobName
)

$packagePath = $relativePackagePath
$definitionFile = $relativeExtensionDefinitionPath

if($env:SYSTEM_ARTIFACTSDIRECTORY -and $env:BUILD_DEFINITIONNAME)
{
    $artifactsDir = Join-Path $env:SYSTEM_ARTIFACTSDIRECTORY $env:BUILD_DEFINITIONNAME
    $packagePath = Join-Path $artifactsDir $relativePackagePath
    $definitionFile = Join-Path $artifactsDir $relativeExtensionDefinitionPath
}

$key = Get-AzureStorageKey -StorageAccountName $storageAccountName
$ctx = New-AzureStorageContext $storageAccountName -StorageAccountKey $key.Primary

Write-Host "Uploading extension package $packagePath to azure storage account $storageAccountName container $storageContainerName blob $storageBlobName"
Set-AzureStorageBlobContent -Container $storageContainerName -File $packagePath -Blob $storageBlobName -Context $ctx -Force

## Commenting this out as Azure PIR replication does not support SAS tokens
#$startTime = Get-Date
#$endTime = $startTime.AddDays(7)
#$sasToken = New-AzureStorageBlobSASToken -Container $storageContainerName -Blob $storageBlobName -Permission r -ExpiryTime $endTime -Context $ctx -FullUri

#$sasToken
#[xml]$definitionXml = [xml](Get-Content $definitionFile)
#$definitionXml.ExtensionImage.MediaLink = [string]$sasToken
#$($definitionXml.ExtensionImage.MediaLink)

#$definitionXml.Save((Resolve-Path $definitionFile))