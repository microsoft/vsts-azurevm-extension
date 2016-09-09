<#
.Synopsis
    Upload extension zip file to a public blob. This blob path is same as specified in extension definition xml file.
    Azure will download this zip from the public blob and will replicate it across its PIR

.Usage
    UploadExtensionPackage.ps1 -relativePackagePath "VM extension\RMExtension.zip" -storageResourceGroup rmvmextensiontest -storageAccountName rmvmextensiontest -storageContainerName agentextension -storageBlobName RMExtension.zip
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$relativePackagePath,

    [Parameter(Mandatory=$true)]
    [string]$storageResourceGroup,
    
    [Parameter(Mandatory=$true)]
    [string]$storageAccountName,
    
    [Parameter(Mandatory=$true)]
    [string]$storageContainerName,

    [Parameter(Mandatory=$true)]
    [string]$storageBlobName
)

$artifactsDir = Join-Path $env:SYSTEM_ARTIFACTSDIRECTORY $env:BUILD_DEFINITIONNAME
$packagePath = Join-Path $artifactsDir "VM extension\RMExtension.zip"

$key = Get-AzureRmStorageAccountKey -ResourceGroupName $storageResourceGroup -Name $storageAccountName
$ctx = New-AzureStorageContext $storageAccountName -StorageAccountKey $key[0].Value

Write-Host "Uploading extension package $packagePath to azure storage account $storageAccountName container $storageContainerName blob $storageBlobName"
Set-AzureStorageBlobContent -Container $storageContainerName -File $packagePath -Blob $storageBlobName -Context $ctx -Force