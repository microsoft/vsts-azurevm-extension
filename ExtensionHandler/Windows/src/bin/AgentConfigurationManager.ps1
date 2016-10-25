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
    [Parameter(Mandatory=$true)]
    [string]$patToken,
    [Parameter(Mandatory=$true)]
    [string]$workingFolder,
    [Parameter(Mandatory=$true)]
    [string]$projectName,
    [Parameter(Mandatory=$true)]
    [string]$machineGroupName,
    [Parameter(Mandatory=$true)]
    [string]$agentName,
    [Parameter(Mandatory=$true)]
    [string]$configCmdPath
    )
    
    $processStartInfo = GetProcessStartInfo
    $processStartInfo.FileName = $configCmdPath
    $processStartInfo.Arguments = "$configCommonArgs --agent $agentName --url $tfsUrl --token $patToken --work $workingFolder --projectname $projectName --machinegroupname $machineGroupName --pool $machineGroupName"
    
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
    [Parameter(Mandatory=$true)]
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
        throw "Agent removal failed with error - $stderr"
    }
}

function ApplyTagsToAgent
{
    param(
    [Parameter(Mandatory=$true)]
    [string]$tfsUrl,
    [Parameter(Mandatory=$true)]
    [string]$projectName,
    [Parameter(Mandatory=$true)]
    [string]$patToken,
    [Parameter(Mandatory=$true)]
    [string]$machineGroupId,    
    [Parameter(Mandatory=$true)]
    [string]$agentId,
    [Parameter(Mandatory=$true)]
    [string]$tagsAsJsonString
    )
    
    $restCallUrl = ( "{0}/{1}/_apis/distributedtask/machinegroups/{2}/Machines?api-version=3.1-preview" -f $tfsUrl, $projectName, $machineGroupId )
    
    WriteAddTagsLog "Url for adding tags - $restCallUrl"
    
    $headers = GetRESTCallHeader $patToken
    
    $requestBody = "[{'tags':" + $tagsAsJsonString + ",'agent':{'id':" + $agentId + "}}]"
    
    WriteAddTagsLog "Add tags request body - $requestBody"

    $ret = Invoke-RestMethod -Uri $($restCallUrl) -headers $headers -Method Patch -ContentType "application/json" -Body $requestBody
    
}

function AddTagsToAgent
{
    param(
    [Parameter(Mandatory=$true)]
    [string]$tfsUrl,
    [Parameter(Mandatory=$true)]
    [string]$projectName,
    [Parameter(Mandatory=$true)]
    [string]$patToken,
    [Parameter(Mandatory=$true)]
    [string]$machineGroupId,    
    [Parameter(Mandatory=$true)]
    [string]$agentId,
    [Parameter(Mandatory=$true)]
    [string]$tagsAsJsonString
    )

    $restCallUrlToGetExistingTags = ( "{0}/{1}/_apis/distributedtask/machinegroups/{2}/Machines?api-version=3.1-preview" -f $tfsUrl, $projectName, $machineGroupId )
    
    WriteAddTagsLog "Url for adding getting existing tags if any - $restCallUrlToGetExistingTags"

    $headers = GetRESTCallHeader $patToken
    
    $machineGroup = Invoke-RestMethod -Uri $($restCallUrlToGetExistingTags) -headers $headers -Method Get -ContentType "application/json"
    
    $existingTags = @()
    for( $i = 0; $i -lt $machineGroup.count; $i++ )
    {
        $eachMachine = $machineGroup.value[$i]
        if( ($eachMachine -ne $null) -and ($eachMachine.agent -ne $null) -and ($eachMachine.agent.id  -eq $agentId) -and ($eachMachine.PSObject.Properties.Match('tags').Count))
        {
            $existingTags += $eachMachine.tags
            break
        }
    }

    $tags = @()
    $newTags =  ( $tagsAsJsonString | ConvertFrom-Json )

    if($existingTags.count -gt 0)
    {    
        $tags = $existingTags    ## Append new tags to existing tags, this will ensure existing tags are not modified due to case change
        WriteAddTagsLog "Found existing tags for agent - $existingTags"
        
        foreach( $newTag in $newTags) 
        {
            if(!($tags -Contains $newTag))
            {
                $tags += $newTag
            }
        }
    }
    else    ## In case not exiting tags are present
    {
        $tags = $newTags
    }
    
    ApplyTagsToAgent -tfsUrl $tfsUrl -projectName $projectName -patToken $patToken -machineGroupId $machineGroupId -agentId $agentId -tagsAsJsonString ($tags | ConvertTo-Json)
}

function GetRESTCallHeader
{
    param(
    [Parameter(Mandatory=$true)]
    [string]$patToken    
    )
    
    $basicAuth = ("{0}:{1}" -f '', $patToken)
    $basicAuth = [System.Text.Encoding]::UTF8.GetBytes($basicAuth)
    $basicAuth = [System.Convert]::ToBase64String($basicAuth)
    $headers = @{Authorization=("Basic {0}" -f $basicAuth)}
    
    return $headers
}