$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\Constants.ps1"

function GetProcessStartInfo
{
    $processStartInfo  = New-Object System.Diagnostics.ProcessStartInfo
    $processStartInfo.WindowStyle = 'Hidden'
    $processStartInfo.CreateNoWindow = $true
    $processStartInfo.UseShellExecute = $false
    $processStartInfo.RedirectStandardError = $true
    $processStartInfo.RedirectStandardOutput = $true

    return $processStartInfo
}

function ConfigureAgent
{
    param(
    [Parameter(Mandatory=$true)]
    [string]$tfsUrl,
    [Parameter(Mandatory=$false)]
    [bool]$isOnPrem = $false,
    [Parameter(Mandatory=$false)]
    [string]$patToken,
    [Parameter(Mandatory=$true)]
    [string]$workingFolder,
    [Parameter(Mandatory=$true)]
    [string]$projectName,
    [Parameter(Mandatory=$true)]
    [string]$deploymentGroupName,
    [Parameter(Mandatory=$true)]
    [string]$agentName,
    [Parameter(Mandatory=$true)]
    [string]$configCmdPath
    )
    
    $processStartInfo = GetProcessStartInfo
    $processStartInfo.FileName = $configCmdPath
    if($isOnPrem){
        $tfsUrl = $tfsUrl.Substring(0,$tfsUrl.LastIndexOf('/'))
    }
    $processStartInfo.Arguments = "$configCommonArgs --agent $agentName --url $tfsUrl --token $patToken --work $workingFolder --projectname $projectName --deploymentgroupname $deploymentGroupName"
    
    $configProcess = New-Object System.Diagnostics.Process
    $configProcess.StartInfo = $processStartInfo
    $configProcess.Start() | Out-Null
    $configProcess.WaitForExit()
    $stdout = $configProcess.StandardOutput.ReadToEnd()
    $stderr = $configProcess.StandardError.ReadToEnd()
    WriteConfigurationLog "ConfigProcess exit code: " + $configProcess.ExitCode
    
    WriteConfigurationLog "$stdout"
    WriteConfigurationLog "$stderr"
    
    if($configProcess.ExitCode -ne 0 )
    {
        throw "Agent Configuration failed with error - $stderr"
    }    
}

function RemoveExistingAgent
{
    param(
    [Parameter(Mandatory=$false)]
    [string]$patToken,
    [Parameter(Mandatory=$true)]
    [string]$configCmdPath    
    )
    
    $processStartInfo = GetProcessStartInfo
    $processStartInfo.FileName = $configCmdPath
    $processStartInfo.Arguments = "$removeAgentArgs --token $patToken"
    $removeAgentProcess = New-Object System.Diagnostics.Process
    $removeAgentProcess.StartInfo = $processStartInfo
    $removeAgentProcess.Start() | Out-Null
    $removeAgentProcess.WaitForExit()
    $stdout = $removeAgentProcess.StandardOutput.ReadToEnd()
    $stderr = $removeAgentProcess.StandardError.ReadToEnd()
    WriteConfigurationLog "RemoveAgentProcess exit code: " + $removeAgentProcess.ExitCode
    
    WriteConfigurationLog "$stdout"
    WriteConfigurationLog "$stderr"

    if($removeAgentProcess.ExitCode -ne 0 )
    {
        $exception = New-Object System.Exception("Agent removal failed with error - $stderr")
        $exception.Data["Reason"] = "UnConfigFailed"
        throw $exception
    }
}

function ApplyTagsToAgent
{
    param(
    [Parameter(Mandatory=$true)]
    [string]$tfsUrl,
    [Parameter(Mandatory=$true)]
    [string]$projectName,
    [Parameter(Mandatory=$false)]
    [string]$patToken,
    [Parameter(Mandatory=$true)]
    [string]$deploymentGroupId,    
    [Parameter(Mandatory=$true)]
    [string]$agentId,
    [Parameter(Mandatory=$true)]
    [string]$machineId,
    [Parameter(Mandatory=$true)]
    [string]$tagsAsJsonString
    )
    
    $restCallUrl = ( "{0}/{1}/_apis/distributedtask/deploymentgroups/{2}/Machines?api-version=3.2-preview" -f $tfsUrl, $projectName, $deploymentGroupId )
    
    WriteAddTagsLog "Url for adding tags - $restCallUrl"
    
    $headers = GetRESTCallHeader $patToken
    
    $requestBody = "[{'id':" + $machineId + ",'tags':" + $tagsAsJsonString + ",'agent':{'id':" + $agentId + "}}]"
    
    WriteAddTagsLog "Add tags request body - $requestBody"
    try
    {
        $ret = Invoke-RestMethod -Uri $($restCallUrl) -headers $headers -Method Patch -ContentType "application/json" -Body $requestBody
        if($ret.PSObject.Properties.name -notcontains "value")
        {
            throw "PATCH call failed"
        }
    }
    catch
    {
        throw "Tags could not be added. Please make sure that you enter correct details."
    }
}

function AddTagsToAgent
{
    param(
    [Parameter(Mandatory=$true)]
    [string]$tfsUrl,
    [Parameter(Mandatory=$true)]
    [string]$projectName,
    [Parameter(Mandatory=$false)]
    [string]$patToken,
    [Parameter(Mandatory=$true)]
    [string]$deploymentGroupId,    
    [Parameter(Mandatory=$true)]
    [string]$agentId,
    [Parameter(Mandatory=$true)]
    [string]$tagsAsJsonString
    )

    $restCallUrlToGetExistingTags = ( "{0}/{1}/_apis/distributedtask/deploymentgroups/{2}/Machines?api-version=3.2-preview" -f $tfsUrl, $projectName, $deploymentGroupId )
    
    WriteAddTagsLog "Url for adding getting existing tags if any - $restCallUrlToGetExistingTags"

    $headers = GetRESTCallHeader $patToken
    try
    {
        $deploymentGroup = Invoke-RestMethod -Uri $($restCallUrlToGetExistingTags) -headers $headers -Method Get -ContentType "application/json"
        $existingTags = @()
        $machineId = "-1";
        for( $i = 0; $i -lt $deploymentGroup.count; $i++ )
        {
            $eachMachine = $deploymentGroup.value[$i]
            if( ($eachMachine -ne $null) -and ($eachMachine.agent -ne $null) -and ($eachMachine.agent.id  -eq $agentId))
            {
                if($eachMachine.PSObject.Properties.Match('tags').Count)
                {
                    $existingTags += $eachMachine.tags
                }
                $machineId = $eachMachine.id
                break
            }
        }

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
    }
    catch
    {
        throw "Tags could not be added. Unable to fetch the existing tags or deployment group details"
    }

    if($machineId -eq "-1")
    {
        WriteAddTagsLog "Tags could not be added. Unable to get the machine id"
        throw "Tags could not be added. Unable to get the machine id"
    }

    WriteAddTagsLog "Updating the tags for agent machine - $machineId"
    ApplyTagsToAgent -tfsUrl $tfsUrl -projectName $projectName -patToken $patToken -deploymentGroupId $deploymentGroupId -agentId $agentId -machineId $machineId -tagsAsJsonString $newTagsJsonString
}

function GetRESTCallHeader
{
    param(
    [Parameter(Mandatory=$false)]
    [string]$patToken    
    )
    
    $basicAuth = ("{0}:{1}" -f '', $patToken)
    $basicAuth = [System.Text.Encoding]::UTF8.GetBytes($basicAuth)
    $basicAuth = [System.Convert]::ToBase64String($basicAuth)
    $headers = @{Authorization=("Basic {0}" -f $basicAuth)}
    
    return $headers
}
