param(
    [Parameter(Mandatory=$true)]
    [hashtable]$config,
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



try
{
    WriteConfigurationLog "Starting the Deployment agent configuration script"
    
    if( ! $(ConfigCmdExists) )
    {
        throw "Unable to find the configuration cmd: $configCmdPath, ensure to download the `
        agent using 'DownloadDeploymentAgent.ps1' before starting the agent configuration"
    }
    
    if([string]::IsNullOrEmpty($agentName))
    {
        $agentName = $env:COMPUTERNAME + "-DG"
        WriteConfigurationLog "Agent name not provided, agent name will be set as $agentName"
    }
    
    WriteConfigurationLog "Configure agent"
    
    ConfigureAgent -tfsUrl $config.VSTSUrl -patToken $config.PATToken -workFolder $defaultAgentWorkFolder `
    -projectName $config.TeamProject -deploymentGroupName $config.DeploymentGroup -agentName $config.AgentName `
    -configCmdPath $(GetConfigCmdPath) -windowsLogonAccountName $windowsLogonAccountName `
    -windowsLogonPassword $windowsLogonPassword
    
    return $returnSuccess 
}
catch
{  
    WriteConfigurationLog $_
    throw $_
}
