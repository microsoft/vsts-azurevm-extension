param(
    [Parameter(Mandatory=$true)]    
    [string]$ResourceGroupName,
    [Parameter(Mandatory=$true)]    
    [string]$VmName,
    [Parameter(Mandatory=$true)]    
    [string]$StorageAccountName,
    [Parameter(Mandatory=$true)]    
    [string]$extension
    )

. "$PSScriptRoot\AzureTestHelper.ps1"

Write-Verbose -Verbose "Cleaning up..."

# Remove extension
Write-Verbose -Verbose "Removing VM extension..."
Remove-AzureRmVMExtension -ResourceGroupName $resourceGroupName -VMName $vmName -Name $extension -Force

#Write-Verbose -Verbose "Removing VM $VmName to ensure clean state for test"
#Remove-ExistingVM -resourceGroupName $ResourceGroupName -vmName $VmName -storageAccountName $StorageAccountName