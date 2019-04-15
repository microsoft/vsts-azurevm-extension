param(
    [Parameter(Mandatory=$true)]
    [string]$tfsUrl,
    [Parameter(Mandatory=$false)]
    [string]$patToken,
    [Parameter(Mandatory=$true)]
    [string]$workingFolder, 
    [Parameter(Mandatory=$true)]
    [string]$tagsAsJsonString  
)

$ErrorActionPreference = 'Stop'
$agentSettingPath = ''

Import-Module $PSScriptRoot\Log.psm1
. "$PSScriptRoot\RMExtensionUtilities.ps1"
. "$PSScriptRoot\Constants.ps1"
. "$PSScriptRoot\AgentConfigurationManager.ps1"

function WriteAddTagsLog
{
    param(
    [string]$logMessage
    )
    
    Write-Log ("[AddTags]: " + $logMessage)
}

function GetAgentSettingPath
{        
    return (Join-Path $workingFolder $agentSetting)
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

    $restCallUrl = ( "{0}/{1}/_apis/distributedtask/deploymentgroups/{2}/Targets?api-version={3}" -f $tfsUrl, $projectId, $deploymentGroupId, $apiVersion)
    WriteAddTagsLog "Url for applying tags - $restCallUrl"
    $headers = @{"Content-Type" = "application/json"}
    $headers += Get-RESTCallHeader -patToken $patToken
    $requestBody = "[{'id':" + $agentId + ",'tags':" + $tagsAsJsonString + ",'agent':{'id':" + $agentId + "}}]"
    WriteAddTagsLog "Add tags request body - $requestBody"

    $applyTagsErrorMessageBlock = {
        $exception = $_
        $message = "An error occured while applying tags. {0}"
        if($exception.Exception.Response)
        {
            $message = $message -f "Status: $($exception.Exception.Response.StatusCode.value__). More details: $($exception.ErrorDetails)"
        }
        else
        {
            $message = $message -f "$($exception.Exception)"
        }
        WriteAddTagsLog $message
        return $message
    }

    $response = Invoke-WithRetry -retryBlock {Invoke-RestMethod -Uri $restCallUrl -Method "Patch" -Body $requestBody -Headers $headers} -actionName "Patch target" `
                                 -retryCatchBlock {$null = (& $applyTagsErrorMessageBlock)} -finalCatchBlock {throw (& $applyTagsErrorMessageBlock)}
    
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

    $restCallUrlToGetExistingTags = ( "{0}/{1}/_apis/distributedtask/deploymentgroups/{2}/Targets/{3}?api-version={4}" -f $tfsUrl, $projectId, $deploymentGroupId, $agentId, $apiVersion)
    WriteAddTagsLog "Url for getting existing tags if any - $restCallUrlToGetExistingTags"
    $headers = Get-RESTCallHeader -patToken $patToken

    $addTagsErrorMessageBlock = {
        $exception = $_
        $message = "Tags could not be added. Unable to fetch the existing tags or deployment group details. {0}"
        if($exception.Exception.Response)
        {
            $message = $message -f "Status: $($exception.Exception.Response.StatusCode.value__). More details: $($exception.ErrorDetails)"
        }
        else
        {
            $message = $message -f "$($exception.Exception)"
        }
        WriteAddTagsLog $message
        return $message
    }
    
    $target = Invoke-WithRetry -retryBlock {Invoke-RestMethod -Uri $restCallUrlToGetExistingTags -Method "Get" -Headers $headers} -actionName "Get target" `
                               -retryCatchBlock {$null = (& $addTagsErrorMessageBlock)} -finalCatchBlock {throw (& $addTagsErrorMessageBlock)}

    $existingTags = if($target.Contains('tags'){$target.tags}else{@()}
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
    WriteAddTagsLog "`t`t` Agent id, Project id, Deployment group id -  $agentId, $projectId, $deploymentGroupId"
    
    if([string]::IsNullOrEmpty($deploymentGroupId) -or [string]::IsNullOrEmpty($agentId) -or [string]::IsNullOrEmpty($projectId))
    {
        throw "Unable to get one or more of the project id, deployment group id, or the agent id. Ensure that the agent is configured before addding tags."
    }
    
    AddTagsToAgent -tfsUrl $tfsUrl -projectId $projectId -patToken $patToken -deploymentGroupId $deploymentGroupId -agentId $agentId -tagsAsJsonString $tagsAsJsonString
    
    return $returnSuccess 
}
catch
{  
    WriteAddTagsLog $_
    throw $_
}
