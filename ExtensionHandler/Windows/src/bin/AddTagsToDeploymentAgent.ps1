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

function ApplyTagsToAgent
{
    param(
    [Parameter(Mandatory=$true)]
    [string]$tfsUrl,
    [Parameter(Mandatory=$true)]
    [string]$projectId,
    [Parameter(Mandatory=$false)]
    [string]$patToken,
    [Parameter(Mandatory=$true)]
    [string]$deploymentGroupId,
    [Parameter(Mandatory=$true)]
    [string]$agentId,
    [Parameter(Mandatory=$true)]
    [string]$tagsAsJsonString
    )

    $restCallUrl = ( "{0}/{1}/_apis/distributedtask/deploymentgroups/{2}/Targets?api-version={3}" -f $tfsUrl, $projectId, $deploymentGroupId, $targetsAPIVersion)

    WriteAddTagsLog "Url for applying tags - $restCallUrl"

    $headers = Get-RESTCallHeader $patToken

    $requestBody = "[{'id':" + $agentId + ",'tags':" + $tagsAsJsonString + ",'agent':{'id':" + $agentId + "}}]"

    WriteAddTagsLog "Add tags request body - $requestBody"
    try
    {
        $response = Invoke-RestMethod -Uri $($restCallUrl) -headers $headers -Method Patch -ContentType "application/json" -Body $requestBody
    }
    catch
    {
        throw "Some error occured while applying tags: $($_.Exception.Response.StatusCode.value__) $($_.Exception.Response.StatusDescription)"
    }
    if($response.PSObject.Properties.name -notcontains "value")
    {
        throw "Tags could not be added"
    }
}

function AddTagsToAgent
{
    param(
    [Parameter(Mandatory=$true)]
    [string]$tfsUrl,
    [Parameter(Mandatory=$true)]
    [string]$projectId,
    [Parameter(Mandatory=$false)]
    [string]$patToken,
    [Parameter(Mandatory=$true)]
    [string]$deploymentGroupId,
    [Parameter(Mandatory=$true)]
    [string]$agentId,
    [Parameter(Mandatory=$true)]
    [string]$tagsAsJsonString
    )

    $restCallUrlToGetExistingTags = ( "{0}/{1}/_apis/distributedtask/deploymentgroups/{2}/Targets/{3}?api-version={4}" -f $tfsUrl, $projectId, $deploymentGroupId, $agentId, $targetsAPIVersion)
    WriteAddTagsLog "Url for getting existing tags if any - $restCallUrlToGetExistingTags"

    $headers = Get-RESTCallHeader $patToken
    try
    {
        $target = Invoke-RestMethod -Uri $($restCallUrlToGetExistingTags) -headers $headers -Method Get -ContentType "application/json"
    }
    catch
    {
        throw "Tags could not be added. Unable to fetch the existing tags or deployment group details: $($_.Exception.Response.StatusCode.value__) $($_.Exception.Response.StatusDescription)"
    }

    $existingTags = $target.tags
    $tags = @()
    [Array]$newTags =  ConvertFrom-Json $tagsAsJsonString

    if($existingTags.count -gt 0)
    {
        $tags = $existingTags    ## Append new tags to existing tags, this will ensure existing tags are not modified due to case change
        WriteAddTagsLog "Found existing tags for agent - $existingTags"

        foreach( $newTag in $newTags)
        {
            if(!($tags -iContains $newTag))
            {
                $tags += $newTag
            }
        }
    }
    else    ## In case not exiting tags are present
    {
        $tags = $newTags
    }

    $newTagsJsonString = ConvertTo-Json $tags

    WriteAddTagsLog "Updating the tags for agent target - $agentId"
    ApplyTagsToAgent -tfsUrl $tfsUrl -projectId $projectId -patToken $patToken -deploymentGroupId $deploymentGroupId -agentId $agentId -tagsAsJsonString $newTagsJsonString
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
    $projectId = $($agentSettings.projectId)
    $deploymentGroupId = $($agentSettings.deploymentGroupId)
    WriteAddTagsLog "`t`t` Agent id, Project id, Deployment group id -  $agentId, $projectId, $deploymentGroupId" -logFunction $logFunction
    
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
