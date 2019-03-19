param(
    [Parameter(Mandatory=$true)]
    [string]$tfsUrl,
    [Parameter(Mandatory=$false)]
    [string]$patToken,
    [Parameter(Mandatory=$true)]
    [string]$projectName,
    [Parameter(Mandatory=$true)]
    [string]$deploymentGroupName,    
    [Parameter(Mandatory=$true)]
    [string]$workingFolder,
    [string]$windowsLogonAccountName,
    [string]$windowsLogonPassword,
    [string]$agentName
)

$ErrorActionPreference = 'Stop'
$configCmdPath = ''

Import-Module $PSScriptRoot\Log.psm1
. "$PSScriptRoot\Constants.ps1"
. "$PSScriptRoot\AgentConfigurationManager.ps1"

function WriteConfigurationLog
{
    param(
    [string]$logMessage
    )
    
    Write-Log ("[Configuration]: " + $logMessage)
}

function GetConfigCmdPath
{
     if([string]::IsNullOrEmpty($configCmdPath))
     {
        $configCmdPath = Join-Path $workingFolder $configCmd
        WriteConfigurationLog "`t`t Configuration cmd path: $configCmdPath"
     }
         
     return $configCmdPath
}

function ConfigCmdExists
{
    $configCmdExists = Test-Path $( GetConfigCmdPath )
    WriteConfigurationLog "`t`t Configuration cmd file exists: $configCmdExists"  
    
    return $configCmdExists    
}

try
{
    WriteConfigurationLog "Starting the Deployment agent configuration script"
    
    if( ! $(ConfigCmdExists) )
    {
        throw "Unable to find the configuration cmd: $configCmdPath, ensure to download the agent using 'DownloadDeploymentAgent.ps1' before starting the agent configuration"
    }
    
    if([string]::IsNullOrEmpty($agentName))
    {
        $agentName = $env:COMPUTERNAME + "-DG"
        WriteConfigurationLog "Agent name not provided, agent name will be set as $agentName"
    }
    
    WriteConfigurationLog "Configure agent"
    
    ConfigureAgent -tfsUrl $tfsUrl -patToken $patToken -workingFolder $defaultAgentWorkFolder -projectName $projectName `
    -deploymentGroupName $deploymentGroupName -agentName $agentName -configCmdPath $(GetConfigCmdPath) `
    -windowsLogonAccountName $windowsLogonAccountName -windowsLogonPassword $windowsLogonPassword
    
    return $returnSuccess 
}
catch
{  
    WriteConfigurationLog $_.Exception
    throw $_.Exception
}
