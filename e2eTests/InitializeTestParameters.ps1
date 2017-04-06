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
                DeploymentGroup       = $publicSettings.DeploymentGroup
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
Set-ReleaseVariable "TemplateFile" $(Join-Path $currentScriptPath $inputs.TemplateFile)
Set-ReleaseVariable "TemplateParameterFile" $(Join-Path $currentScriptPath $inputs.TemplateParameterFile)
$windowsExtensionPublicSettingsFile = Join-Path $currentScriptPath $inputs.windowsExtensionPublicSettingsFile
Set-ReleaseVariable "windowsExtensionName" $($inputs.windowsExtensionName)
Set-ReleaseVariable "windowsExtensionPublisher" $($inputs.windowsExtensionPublisher)

Set-ReleaseVariable "linuxVmName" $($inputs.linuxVmName)
Set-ReleaseVariable "linuxVmStorageAccountName" $($inputs.linuxVmStorageAccountName)
$linuxExtensionPublicSettingsFile = Join-Path $currentScriptPath $inputs.linuxExtensionPublicSettingsFile
Set-ReleaseVariable "linuxExtensionName" $($inputs.linuxExtensionName)
Set-ReleaseVariable "linuxExtensionPublisher" $($inputs.linuxExtensionPublisher)

# get config settings
$config = Get-Config -extensionPublicSettingsFile $windowsExtensionPublicSettingsFile
Set-ReleaseVariable "VSTSAccountName" $($config.VSTSUrl)
Set-ReleaseVariable "TeamProject" $($config.TeamProject)
Set-ReleaseVariable "DeploymentGroup" $($config.DeploymentGroup)
Set-ReleaseVariable "WindowsAgentName" $($config.AgentName)
$config = Get-Config -extensionPublicSettingsFile $linuxExtensionPublicSettingsFile
Set-ReleaseVariable "LinuxAgentName" $($config.AgentName)