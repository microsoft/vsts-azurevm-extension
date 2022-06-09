<#
.Synopsis
    Currently there is no good way to know latest version of a VM extension from Azure. Hence, we are doing additional book-keeping to get/update latest version details.
    The version will be stored in a blob(currently in same container as which is used for extension zip package). Once a new extension version is successfully updated in PIR,
    the blob's content will updated to reflect this new version. Also, old version is noted down and used to delete older version of extension from PIR

.Usage
    UpdateExtensionVersionInformation.ps1 -relativeExtensionDefinitionPath "VM extension\ExtensionDefinition_Test_MIGRATED.xml" -storageResourceGroup rmvmextensiontest -storageAccountName rmvmextensiontest -storageContainerName agentextension -storageBlobName LatestVersion
#>

[CmdletBinding()]
param(
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

$artifactsDir = Join-Path $env:SYSTEM_ARTIFACTSDIRECTORY $env:BUILD_DEFINITIONNAME
$definitionFile = Join-Path $artifactsDir $relativeExtensionDefinitionPath

[xml]$bodyxml = Get-Content $definitionFile

# get the current version from artifact's extension defintion file
$currentVersion = $bodyxml.ExtensionImage.Version
Write-Host "New version of extension: $currentVersion"
$currentVersionLocalFile = "$artifactsDir\latestVersion.txt"
Write-Host "Using local file $currentVersionLocalFile to store new version for uploading purpose"

$key = Get-AzureRmStorageAccountKey -ResourceGroupName $storageResourceGroup -Name $storageResourceGroup
$ctx = New-AzureStorageContext -StorageAccountName $storageResourceGroup -StorageAccountKey $key[0].Value

$oldVersionLocalFile = "$artifactsDir\oldVersion.txt"
Write-Host "Using local file $oldVersionLocalFile for downloading old version information"

Write-Host "Downloading version information from azure storage account $storageAccountName container $storageContainerName blob $storageBlobName"
# get old version detail from blob
Get-AzureStorageBlobContent -Container $storageContainerName -Blob $storageBlobName -Context $ctx -Destination $oldVersionLocalFile -ErrorAction Ignore -Force

$oldVersion = $null
if(Test-Path $oldVersionLocalFile)
{
    $oldVersion = Get-Content $oldVersionLocalFile
}

Write-Host "old version: $oldVersion"

if(($oldVersion -ne $null) -and ($oldVersion -ne $currentVersion))
{
    # set this version as value for release variable 
    $oldVersionVariable = "OldVersionToBeDeleted"
    Write-Host "##vso[task.setvariable variable=$oldVersionVariable;]$oldVersion"
}

# update blob with current version as latest version
Write-Host "Updating blob with new version information"
New-Item -ItemType File -Path $currentVersionLocalFile -Value $currentVersion -Force
Set-AzureStorageBlobContent -Container $storageContainerName -File $currentVersionLocalFile -Blob $storageBlobName -Context $ctx -Force