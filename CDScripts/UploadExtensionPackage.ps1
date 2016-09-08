<#
.Synopsis
    Upload extension zip file to a public blob. This blob path is same as specified in extension definition xml file.
    Azure will download this zip from the public blob and will replicate it across its PIR
#>

$artifactsDir = Join-Path $env:SYSTEM_ARTIFACTSDIRECTORY $env:BUILD_DEFINITIONNAME
$packagePath = Join-Path $artifactsDir "VM extension\RMExtension.zip"

$key = Get-AzureRmStorageAccountKey -ResourceGroupName rmvmextensiontest -Name rmvmextensiontest
$ctx = New-AzureStorageContext rmvmextensiontest -StorageAccountKey $key[0].Value

Set-AzureStorageBlobContent -Container agentextension -File $packagePath -Blob RMExtension.zip -Context $ctx -Force