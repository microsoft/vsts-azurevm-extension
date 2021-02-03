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
    
    try
    {
        #If the resource group exists
        Get-AzureRmResourceGroup -Name $resourceGroupName -ErrorAction Stop
        # Delete existing VM if any. Remove-AzureRmVM does not throw if VM does not exist, hence no need to handle exception
        Remove-AzureRmVM -ResourceGroupName $resourceGroupName -Name $vmName -Force

        #If the storage account exists
        Get-AzureRmStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName -ErrorAction Stop
        # Delete VM's vhd blob as creating VM again will require blob to be removed first
        $storageKey = Get-AzureRmStorageAccountKey -ResourceGroupName $resourceGroupName -Name $storageAccountName
        $storageCtx = New-AzureStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageKey[0].Value
        Get-AzureStorageBlob -Container vhds -Context $storageCtx | Remove-AzureStorageBlob
    }
    catch
    {
        #If the error message is neither of (1)resource group does not exist, (2)storage account does not exist, delete the resource group
        $exceptionMessage = $_.Exception.Message
        if(-not($exceptionMessage.Contains("Provided resource group does not exist") -or 
        $exceptionMessage.Contains("The Resource 'Microsoft.Storage/storageAccounts/$storageAccountName' under resource group '$resourceGroupName' was not found.")))
        {
            try 
            {
                Write-Host "Some unexpected error occured, deleting resource group: $_"
                Remove-AzureRmResourceGroup -Name $resourceGroupName -Force -ErrorAction Stop
            }
            catch {
                Write-Host "Deleting resource group failed: $_"
            }
        }
    }
}

function Create-VM
{
    param(
    [string]$resourceGroupName,
    [string]$templateFile,
    [string]$templateParameterFile,
    [string]$vmPasswordString
    )
    
    #Ensure Resource Group exists
    try
    {
        Get-AzureRmResourceGroup -Name $resourceGroupName -ErrorAction Stop
    }
    catch
    {
        if($_.Exception.Message.Contains("Provided resource group does not exist"))
        {
            Write-Host "Rsource group does not exist. Creating it."
            New-AzureRmResourceGroup -Name $resourceGroupName -Location southcentralus -Tag @{DaysToDelete = "Never"}
        }
        else
        {
            throw "An error occured while fetching the resource group: $_"
        }
    }

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
                DeploymentGroup    = $publicSettings.DeploymentGroup
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
$extensionReconfigurationPublicSettingsFile = Join-Path $currentScriptPath $inputs.extensionPublicSettingsFileReconfigure
$extensionProtectedSettingsFile = Join-Path $currentScriptPath $inputs.extensionProtectedSettingsFile

# Only keep major and minor version for extension
$parts = $extensionVersion.split(".")
$extensionVersion = "{0}.{1}" -f $parts[0], $parts[1]

#create protected settings file with pat token
@{ PATToken = $personalAccessToken } | ConvertTo-Json | Set-Content -Path $extensionProtectedSettingsFile -Force

#####
# Pre-cleanup
#####
Write-Host "Removing VM $vmName to ensure clean state for test"
Remove-ExistingVM -resourceGroupName $resourceGroupName -vmName $vmName -storageAccountName $storageAccountName

####
# Create VM
Write-Host "Creating VM $vmName"
Create-VM -resourceGroupName $resourceGroupName -templateFile $templateFile -templateParameterFile $templateParameterFile -vmPasswordString $vmPassword
####

# Run twice. First configure and then reconfigure 
@($extensionPublicSettingsFile, $extensionReconfigurationPublicSettingsFile) | foreach {
    # get config settings
    $config = Get-Config -extensionPublicSettingsFile $_ -extensionProtectedSettingsFile $extensionProtectedSettingsFile -personalAccessToken $personalAccessToken

    ####
    # Remove any old agent which is till registered
    ####
    $oldAgentInfo = Get-VSTSAgentInformation -vstsUrl $config.VSTSUrl -teamProject $config.TeamProject -patToken $config.PATToken -deploymentGroup $config.DeploymentGroup -agentName $config.AgentName
    if($oldAgentInfo.isAgentExists -eq $true) {
        Remove-VSTSAgent -vstsUrl $config.VSTSUrl -teamProject $config.TeamProject -patToken $config.PATToken -deploymentGroupId $oldAgentInfo.deploymentGroupId -agentId $oldAgentInfo.agentId
    }

    #####
    # Run scenario
    #####

    Write-Host "Installing extension $extension version $extensionVersion on VM $vmName"
    Install-ExtensionOnVM -resourceGroupName $resourceGroupName -vmName $vmName -location $location -publisher $publisher -extension $extension -extensionVersion $extensionVersion -extensionPublicSettingsFile $_ -extensionProtectedSettingsFile $extensionProtectedSettingsFile

    #####
    # Validation
    #####

    # Verify that agent is correctly configured against VSTS
    # Some delay has been observed, causing e2e tests to break, so adding sleep.
    Start-Sleep -s 60
    Write-Host "Validating that agent has been registered..."
    Write-Host "Getting agent information from VSTS"
    $agentInfo = Get-VSTSAgentInformation -vstsUrl $config.VSTSUrl -teamProject $config.TeamProject -patToken $config.PATToken -deploymentGroup $config.DeploymentGroup -agentName $config.AgentName

    if(($agentInfo.isAgentExists -eq $false) -or ($agentInfo.isAgentOnline -eq $false)) {
        Write-Error "Agent has not been registered with VSTS!!"
    }
    else {
        Write-Host "Agent has been successfully registered with VSTS!!"
    }    
}



#####
# Clean-up
#####

Write-Host "Cleaning up..."
# Remove extension
Remove-AzureRmVMExtension -ResourceGroupName $resourceGroupName -VMName $vmName -Name $extension -Force

# Delete VM and vhd
Remove-ExistingVM -resourceGroupName $resourceGroupName -vmName $vmName -storageAccountName $storageAccountName

# Cleanup both agents if required pool if needed
@($extensionPublicSettingsFile, $extensionReconfigurationPublicSettingsFile) | foreach {
    # get config settings
    $config = Get-Config -extensionPublicSettingsFile $_ -extensionProtectedSettingsFile $extensionProtectedSettingsFile -personalAccessToken $personalAccessToken
    $agentInfo = Get-VSTSAgentInformation -vstsUrl $config.VSTSUrl -teamProject $config.TeamProject -patToken $config.PATToken -deploymentGroup $config.DeploymentGroup -agentName $config.AgentName

    # Remove agent from pool if needed
    if($agentInfo.isAgentExists -eq $true) {
        Remove-VSTSAgent -vstsUrl $config.VSTSUrl -teamProject $config.TeamProject -patToken $config.PATToken -deploymentGroupId $agentInfo.deploymentGroupId -agentId $agentInfo.agentId
    }
}

# Delete protected settings file
if(Test-Path $extensionProtectedSettingsFile)
{
    Remove-Item -Path $extensionProtectedSettingsFile -Force
}
