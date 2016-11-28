param(
    [Parameter(Mandatory=$true)]    
    [string]$ResourceGroupName,
    [Parameter(Mandatory=$true)]    
    [string]$VmName,
    [Parameter(Mandatory=$true)]    
    [string]$StorageAccountName
    )

. "$PSScriptRoot\AzureTestHelper.ps1"

Write-Host "Removing VM $VmName to ensure clean state for test"
Remove-ExistingVM -resourceGroupName $ResourceGroupName -vmName $VmName -storageAccountName $StorageAccountName