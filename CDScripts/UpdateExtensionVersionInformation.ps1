<#
.Synopsis
    Currently there is no good way to know latest version of a VM extension from Azure. Hence, we are doing additional book-keeping to get/update latest version details.
    The version will be stored in a blob(currently in same container as which is used for extension zip package). Once a new extension version is successfully updated in PIR,
    the blob's content will updated to reflect this new version. Also, old version is noted down and used to delete older version of extension from PIR 
#>

$artifactsDir = Join-Path $env:SYSTEM_ARTIFACTSDIRECTORY $env:BUILD_DEFINITIONNAME
$definitionFile = Join-Path $artifactsDir "VM extension\ExtensionDefinition_Test.xml"

[xml]$bodyxml = Get-Content $definitionFile

# get the current version from artifact's extension defintion file
$currentVersion = $bodyxml.ExtensionImage.Version
$currentVersion
$currentVersionLocalFile = "$artifactsDir\latestVersion.txt"
$currentVersionLocalFile

$key = Get-AzureRmStorageAccountKey -ResourceGroupName rmvmextensiontest -Name rmvmextensiontest
$ctx = New-AzureStorageContext rmvmextensiontest -StorageAccountKey $key[0].Value

$oldVersionLocalFile = "$artifactsDir\oldVersion.txt"
$oldVersionLocalFile

# get old version detail from blob
Get-AzureStorageBlobContent -Container agentextension -Blob LatestVersion -Context $ctx -Destination $oldVersionLocalFile -ErrorAction Ignore -Force

$oldVersion = $null
if(Test-Path $oldVersionLocalFile)
{
    $oldVersion = Get-Content $oldVersionLocalFile
    $oldVersion
}

if(($oldVersion -ne $null) -and ($oldVersion -ne $currentVersion))
{
    # set this version as value for release variable 
    $oldVersionVariable = "OldVersionToBeDeleted"
    Write-Host "##vso[task.setvariable variable=$oldVersionVariable;]$oldVersion"
}

# update blob with current version as latest version
New-Item -ItemType File -Path $currentVersionLocalFile -Value $currentVersion -Force
Set-AzureStorageBlobContent -Container agentextension -File $currentVersionLocalFile -Blob LatestVersion -Context $ctx -Force