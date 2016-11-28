function Remove-ExistingVM
{
    param(
    [string]$resourceGroupName,
    [string]$vmName,
    [string]$storageAccountName
    )
    
    # Delete existing VM if any. Remove-AzureRmVM does not throw if VM does not exist, hence no need to handle exception
    Remove-AzureRmVM -ResourceGroupName $resourceGroupName -Name $vmName -Force

    # Delete VM's vhd blob as creating VM again will require blob to be removed first
    $storageKey = Get-AzureRmStorageAccountKey -ResourceGroupName $resourceGroupName -Name $storageAccountName
    $storageCtx = New-AzureStorageContext $storageAccountName -StorageAccountKey $storageKey[0].Value
    Get-AzureStorageBlob -Container vhds -Context $storageCtx | Remove-AzureStorageBlob
}

function Create-VM
{
    param(
    [string]$resourceGroupName,
    [string]$templateFile,
    [string]$templateParameterFile,
    [string]$vmPasswordString
    )
    
    # Create VM using template
    $vmPasswordSecureString = $vmPasswordString | ConvertTo-SecureString -AsPlainText -Force
    $deploymentName = Get-Date -Format yyyyMMddhhmmss
    New-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile $templateFile -TemplateParameterFile $templateParameterFile -adminPassword $vmPasswordSecureString -DeploymentName $deploymentName
}

function Install-ExtensionOnVM
{
    param(
    [string]$resourceGroupName,
    [string]$vmName,
    [string]$location,
    [string]$publisher,
    [string]$extension,
    [string]$extensionVersion,
    [string]$extensionPublicSettingsFile,
    [string]$extensionProtectedSettingsFile
    )
    
    # Install extension on VM
    $publicSettings = Get-Content $extensionPublicSettingsFile | Out-String
    $protectedSettings = Get-Content $extensionProtectedSettingsFile | Out-String
    Set-AzureRmVMExtension -Publisher $publisher -ExtensionType $extension -ResourceGroupName $resourceGroupName -VMName $vmName -SettingString $publicSettings -ProtectedSettingString $protectedSettings -TypeHandlerVersion $extensionVersion -Location $location -Name $extension
}