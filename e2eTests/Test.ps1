# Usage: .\Test.ps1 -testEnvironmentFile TestEnvironment.json -publisher Test.Microsoft.VisualStudio.Services -extension TeamServicesAgent -extensionVersion 1.30 [-personalAccessToken ***] -vmPassword ***

param(
    [Parameter(Mandatory=$true)]
    [string]$testEnvironmentFile,
    [Parameter(Mandatory=$true)]
    [string]$vmPassword,
    [Parameter(Mandatory=$true)]
    [string]$publisher,
    [Parameter(Mandatory=$true)]
    [string]$extension,
    [Parameter(Mandatory=$true)]
    [string]$extensionVersion,
    [string]$personalAccessToken
)

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

function Get-Config
{
    param(
    [string]$extensionPublicSettingsFile,
    [string]$extensionProtectedSettingsFile,
    [string]$personalAccessToken
    )
    
    $publicSettings = Get-Content $extensionPublicSettingsFile | Out-String | ConvertFrom-Json
    $protectedSettings = Get-Content $extensionProtectedSettingsFile | Out-String | ConvertFrom-Json

    if(($personalAccessToken -ne $null) -and ($personalAccessToken -ne ""))
    {
        $token = $personalAccessToken
    }
    else
    {
        $token = $protectedSettings.PATToken
    }

    return @{
                VSTSUrl            = $publicSettings.VSTSAccountName
                TeamProject        = $publicSettings.TeamProject
                MachineGroup       = $publicSettings.MachineGroup
                AgentName          = $publicSettings.AgentName
                PATToken           = $token
            }
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

$currentScriptPath = $PSScriptRoot
. "$currentScriptPath\VSTSAgentTestHelper.ps1"

#####
# Read inputs
#####
$inputs = Get-Content (Join-Path $currentScriptPath $testEnvironmentFile) | Out-String | ConvertFrom-Json
$resourceGroupName = $inputs.resourceGroupName
$vmName = $inputs.vmName
$location = $inputs.location
$storageAccountName = $inputs.storageAccountName
$templateFile = Join-Path $currentScriptPath $inputs.templateFile
$templateParameterFile = Join-Path $currentScriptPath $inputs.templateParameterFile
$extensionPublicSettingsFile = Join-Path $currentScriptPath $inputs.extensionPublicSettingsFile
$extensionProtectedSettingsFile = Join-Path $currentScriptPath $inputs.extensionProtectedSettingsFile

# Only keep major and minor version for extension
$parts = $extensionVersion.split(".")
$extensionVersion = "{0}.{1}" -f $parts[0], $parts[1]

#create protected settings file with pat token
@{ PATToken = $personalAccessToken } | ConvertTo-Json | Set-Content -Path $extensionProtectedSettingsFile -Force

# get config settings
$config = Get-Config -extensionPublicSettingsFile $extensionPublicSettingsFile -extensionProtectedSettingsFile $extensionProtectedSettingsFile -personalAccessToken $personalAccessToken

#####
# Pre-cleanup
#####
Write-Host "Removing VM $vmName to ensure clean state for test"
Remove-ExistingVM -resourceGroupName $resourceGroupName -vmName $vmName -storageAccountName $storageAccountName

# Remove any old agent which is till registered
$oldAgentInfo = Get-VSTSAgentInformation -vstsUrl $config.VSTSUrl -teamProject $config.TeamProject -patToken $config.PATToken -machineGroup $config.MachineGroup -agentName $config.AgentName
if($oldAgentInfo.isAgentExists -eq $true)
{
    Remove-VSTSAgent -vstsUrl $config.VSTSUrl -patToken $config.PATToken -poolId $oldAgentInfo.poolId -agentId $oldAgentInfo.agentId
}

#####
# Run scenario
#####
Write-Host "Creating VM $vmName"
Create-VM -resourceGroupName $resourceGroupName -templateFile $templateFile -templateParameterFile $templateParameterFile -vmPasswordString $vmPassword

for($i=0;$i -lt 150; $i++){
    Start-Sleep -s 2
    "Hello World"
}

Write-Host "Installing extension $extension version $extensionVersion on VM $vmName"
Install-ExtensionOnVM -resourceGroupName $resourceGroupName -vmName $vmName -location $location -publisher $publisher -extension $extension -extensionVersion $extensionVersion -extensionPublicSettingsFile $extensionPublicSettingsFile -extensionProtectedSettingsFile $extensionProtectedSettingsFile

#####
# Validation
#####

# Verify that agent is correctly configured against VSTS
Write-Host "Validating that agent has been registered..."
Write-Host "Getting agent information from VSTS"
$agentInfo = Get-VSTSAgentInformation -vstsUrl $config.VSTSUrl -teamProject $config.TeamProject -patToken $config.PATToken -machineGroup $config.MachineGroup -agentName $config.AgentName

if(($agentInfo.isAgentExists -eq $false) -or ($agentInfo.isAgentOnline -eq $false))
{
    Write-Error "Agent has not been registered with VSTS!!"
}
else
{
    Write-Host "Agent has been successfully registered with VSTS!!"
}

#####
# Clean-up
#####

Write-Host "Cleaning up..."
# Remove extension
Remove-AzureRmVMExtension -ResourceGroupName $resourceGroupName -VMName $vmName -Name $extension -Force

# Delete VM and vhd
Remove-ExistingVM -resourceGroupName $resourceGroupName -vmName $vmName -storageAccountName $storageAccountName

# Remove agent from pool if needed
if($agentInfo.isAgentExists -eq $true)
{
    Remove-VSTSAgent -vstsUrl $config.VSTSUrl -patToken $config.PATToken -poolId $agentInfo.poolId -agentId $agentInfo.agentId
}

# Delete protected settings file
if(Test-Path $extensionProtectedSettingsFile)
{
    Remove-Item -Path $extensionProtectedSettingsFile -Force
}