param(
    [Parameter(Mandatory=$true)]
    [string]$tfsUrl,
    [Parameter(Mandatory=$true)]
    [string]$patToken,
    [Parameter(Mandatory=$true)]
    [string]$projectName,
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
        throw "Unable to find the .agent file $agentSettingPath. Ensure to configure the agent before adding tags to it"
    }
    
    $agentSettings = Get-Content -Path $agentSettingPath | Out-String | ConvertFrom-Json
    
    $agentId = $($agentSettings.agentId)
    $machineGroupId = ""
    ## try catch is only for back-compat, old execution may not have machineGroupId saved in agent setting
    try
    {
        $machineGroupId = $($agentSettings.machineGroupId)
    }
    catch{  }
    
    
    if([string]::IsNullOrEmpty($machineGroupId) -or [string]::IsNullOrEmpty($agentId))
    {
        throw "Unable to get the machineGroupId or agent id with .agent file from $workingFolder. Ensure before adding tags, agent is configured"
    }
    
    AddTagsToAgent -tfsUrl $tfsUrl -projectName $projectName -patToken $patToken -machineGroupId $machineGroupId -agentId $agentId -tagsAsJsonString $tagsAsJsonString
    
    return $returnSuccess 
}
catch
{  
    WriteAddTagsLog $_.Exception
    throw $_.Exception
}
