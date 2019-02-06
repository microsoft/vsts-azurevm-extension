param(
    [Parameter(Mandatory=$true)]
    [string]$tfsUrl,
    [Parameter(Mandatory=$false)]
    [string]$patToken,
    [Parameter(Mandatory=$true)]
    [string]$workingFolder, 
    [Parameter(Mandatory=$true)]
    [string]$tagsAsJsonString,    
    [scriptblock]$logFunction    
)

$ErrorActionPreference = 'Stop'
$agentSettingPath = ''

. "$PSScriptRoot\Constants.ps1"
. "$PSScriptRoot\AgentConfigurationManager.ps1"

function WriteAddTagsLog
{
    param(
    [string]$logMessage
    )
    
    $log = "[AddTags]: " + $logMessage
    if($logFunction -ne $null)
    {
        $logFunction.Invoke($log)
    }
    else
    {
        write-verbose $log
    }
}

function GetAgentSettingPath
{        
    return Join-Path $workingFolder $agentSetting
}

function AgentSettingExist
{
    $agentSettingExists = Test-Path $agentSettingPath
    WriteAddTagsLog "`t`t Agent setting file exists: $agentSettingExists"  
    
    return $agentSettingExists    
}

try
{
    WriteAddTagsLog "Adding the tags for configured agent"
    
    $agentSettingPath = GetAgentSettingPath
    
    WriteAddTagsLog "`t`t Agent setting path: $agentSettingPath"   
    
    if( ! $(AgentSettingExist) )
    {
        throw "Unable to find the .agent file $agentSettingPath. Ensure that the agent is configured before addding tags."
    }
    
    $agentSettings = Get-Content -Path $agentSettingPath | Out-String | ConvertFrom-Json
    
    $agentId = $($agentSettings.agentId)
    $projectId = ""
    $deploymentGroupId = ""
    try
    {
        $projectId = $($agentSettings.projectId)
        $deploymentGroupId = $($agentSettings.deploymentGroupId)
        WriteLog "`t`t` Project id -  $projectId" -logFunction $logFunction
        WriteLog "`t`t` Deployment group id -  $deploymentGroupId" -logFunction $logFunction
    }
    catch{}
    
    if([string]::IsNullOrEmpty($deploymentGroupId) -or [string]::IsNullOrEmpty($agentId) -or [string]::IsNullOrEmpty($projectId))
    {
        throw "Unable to get one or more of the project id, deployment group id, or the agent id. Ensure that the agent is configured before addding tags."
    }
    
    AddTagsToAgent -tfsUrl $tfsUrl -projectId $projectId -patToken $patToken -deploymentGroupId $deploymentGroupId -agentId $agentId -tagsAsJsonString $tagsAsJsonString
    
    return $returnSuccess 
}
catch
{  
    WriteAddTagsLog $_.Exception
    throw $_.Exception
}
