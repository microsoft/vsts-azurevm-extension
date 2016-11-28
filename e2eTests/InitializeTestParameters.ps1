param(
    [Parameter(Mandatory=$true)]
    [string]$testEnvironmentFile
)

function Get-Config
{
    param(
    [string]$extensionPublicSettingsFile,
    [string]$personalAccessToken
    )
    
    $publicSettings = Get-Content $extensionPublicSettingsFile | Out-String | ConvertFrom-Json

    return @{
                VSTSUrl            = $publicSettings.VSTSAccountName
                TeamProject        = $publicSettings.TeamProject
                MachineGroup       = $publicSettings.MachineGroup
                AgentName          = $publicSettings.AgentName
            }
}

function Set-ReleaseVariable
{
    param(
    [string]$variableName,
    [string]$variableValue
    )

    Write-Host "##vso[task.setvariable variable=$variableName;]$variableValue"
}

$currentScriptPath = $PSScriptRoot

#####
# Read inputs
#####
$inputs = Get-Content (Join-Path $currentScriptPath $testEnvironmentFile) | Out-String | ConvertFrom-Json
Set-ReleaseVariable "resourceGroupName" $($inputs.resourceGroupName)
Set-ReleaseVariable "windowsVmName" $($inputs.windowsVmName)
Set-ReleaseVariable "location" $($inputs.location)
Set-ReleaseVariable "windowsVmStorageAccountName" $($inputs.windowsVmStorageAccountName)
Set-ReleaseVariable "windowsVmTemplateFile" $(Join-Path $currentScriptPath $inputs.windowsVmTemplateFile)
Set-ReleaseVariable "windowsVmTemplateParameterFile" $(Join-Path $currentScriptPath $inputs.windowsVmTemplateParameterFile)
$windowsExtensionPublicSettingsFile = Join-Path $currentScriptPath $inputs.windowsExtensionPublicSettingsFile
Set-ReleaseVariable "windowsExtensionName" $($inputs.windowsExtensionName)
Set-ReleaseVariable "windowsExtensionPublisher" $($inputs.windowsExtensionPublisher)

# get config settings
$config = Get-Config -extensionPublicSettingsFile $windowsExtensionPublicSettingsFile
Set-ReleaseVariable "VSTSAccountName" $($config.VSTSUrl)
Set-ReleaseVariable "TeamProject" $($config.TeamProject)
Set-ReleaseVariable "MachineGroup" $($config.MachineGroup)
Set-ReleaseVariable "WindowsAgentName" $($config.AgentName)