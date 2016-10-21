<#
.Synopsis
    Creates a SAS token for VM extension package blob.

.Usage
    UploadExtensionPackage.ps1 -storageResourceGroup rmvmextensiontest -storageAccountName rmvmextensiontest -storageContainerName agentextension -storageBlobName RMExtension.zip
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$storageResourceGroup,
    
    [Parameter(Mandatory=$true)]
    [string]$storageAccountName,
    
    [Parameter(Mandatory=$true)]
    [string]$storageContainerName,

    [Parameter(Mandatory=$true)]
    [string]$storageBlobName
)

$key = Get-AzureStorageKey -StorageAccountName $storageAccountName
$ctx = New-AzureStorageContext $storageAccountName -StorageAccountKey $key.Primary

$startTime = Get-Date
$endTime = $startTime.AddYears(5)
$sasToken = New-AzureStorageBlobSASToken -Container $storageContainerName -Blob $storageBlobName -Permission r -StartTime $startTime -ExpiryTime $endTime -Context $ctx
Write-Host "SAS token for blob $storageBlobName in container $storageContainerName : $sasToken"
