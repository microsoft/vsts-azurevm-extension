$ErrorActionPreference = 'Stop'
Import-Module $PSScriptRoot\Log.psm1
. "$PSScriptRoot\RMExtensionUtilities.ps1"
. "$PSScriptRoot\Constants.ps1"

function Test-ConfiguredAgentExists
{
    param(
        [Parameter(Mandatory=$true)]
        [string]$workingFolder
    )

    try
    {
        WriteAgentSettingsHelperLog "Check if any existing agent is running from $workingFolder"
    
        $agentSettingFileExist = Test-Path $(GetAgentSettingFilePath $workingFolder)
        WriteAgentSettingsHelperLog "`t`t Agent setting file exist: $agentSettingFileExist"
    
        return $agentSettingFileExist 
    }
    catch
    {  
        WriteAgentSettingsHelperLog $_
        throw $_
    }
}

function Test-AgentSettingsAreSame
{
    param(
        [Parameter(Mandatory=$true)]
        [string]$workingFolder,
        [Parameter(Mandatory=$true)]
        [string]$tfsUrl,
        [Parameter(Mandatory=$true)]
        [string]$projectName,
        [Parameter(Mandatory=$true)]
        [string]$deploymentGroupName,
        [Parameter(Mandatory=$false)]
        [string]$patToken
    )

    try
    {
        WriteAgentSettingsHelperLog "AgentReConfigurationRequired check started."
        
        $agentSettingFile = GetAgentSettingFilePath $workingFolder        

        if( !(Test-Path $agentSettingFile) )
        {
            WriteAgentSettingsHelperLog "`t`t Agent setting file $agentSettingFile does not exist"
            return $true
        }
        WriteAgentSettingsHelperLog "`t`tReading agent setting file - $agentSettingFile"
        
        $agentSetting = Get-AgentSettings $agentSettingFile
        
        $tfsUrl = $tfsUrl.TrimEnd('/')
        $agentTfsUrl = $agentSetting.serverUrl.TrimEnd('/')
        $deploymentGroupDataAsPerSetting = $null
        $agentCollection = ""
        try
        {
            $agentUrl = $agentTfsUrl
            $agentCollection = if([bool]($agentSetting.PSObject.Properties.name -match "collectionName")){$agentSetting.collectionName}
            if($agentCollection)
            {
                $agentUrl = -join($agentUrl, '/', $agentCollection)
            }
            
            WriteAgentSettingsHelperLog "`t`tCall GetDeploymentGroupDataFromAgentSetting"
            $deploymentGroupDataAsPerSetting = GetDeploymentGroupDataFromAgentSetting -agentSetting $agentSetting -tfsUrl $agentUrl -patToken $patToken
        }
        catch
        {
            WriteAgentSettingsHelperLog "`t`t`t Unable to get the deployment group data: $_"
        }

        $tfsUrl = if ($tfsUrl.StartsWith($agentUrl, "CurrentCultureIgnoreCase")) {$agentUrl} else {$tfsUrl}

        if(!$deploymentGroupDataAsPerSetting)
        {
            WriteAgentSettingsHelperLog "`t`t`t Test-AgentSettingsAreSame Return : false (Unable to get the deployment group data from existing agent settings)"
            return $false;
        }
        
        WriteAgentSettingsHelperLog "`t`t`t Agent Configured With `t`t`t`t`t Agent Need To Be Configured With"
        WriteAgentSettingsHelperLog "`t`t`t $agentUrl `t`t`t`t`t $tfsUrl"
        WriteAgentSettingsHelperLog "`t`t`t $($deploymentGroupDataAsPerSetting.project.name) `t`t`t`t`t $projectName"
        WriteAgentSettingsHelperLog "`t`t`t $($deploymentGroupDataAsPerSetting.name) `t`t`t`t`t $deploymentGroupName"
        if( ([string]::Compare($tfsUrl, $agentUrl, $True) -eq 0) -and ([string]::Compare($projectName, $($deploymentGroupDataAsPerSetting.project.name), $True) -eq 0) -and ([string]::Compare($deploymentGroupName, $($deploymentGroupDataAsPerSetting.name), $True) -eq 0) )
        {
            WriteAgentSettingsHelperLog "`t`t`t Test-AgentSettingsAreSame Return : true"        
            return $true
        }
        WriteAgentSettingsHelperLog "`t`t`t Test-AgentSettingsAreSame Return : false"        
        return $false
    }
    catch
    {  
        WriteAgentSettingsHelperLog $_
        throw $_
    }
}

function Get-AgentSettings
{
    param(
    [string]$agentSettingFile
    )
    
    return ( Get-Content -Path $agentSettingFile | Out-String | ConvertFrom-Json)
}

function GetDeploymentGroupDataFromAgentSetting
{
    param(
    [Parameter(Mandatory=$true)]
    [object]$agentSetting,
    [Parameter(Mandatory=$true)]
    [string]$tfsUrl,    
    [Parameter(Mandatory=$false)]
    [string]$patToken
    )
    
    $projectId = $($agentSetting.projectId)
    $deploymentGroupId = $($agentSetting.deploymentGroupId)
    WriteAgentSettingsHelperLog "`t`t` Project id, Deployment group id -  $projectId, $deploymentGroupId"
    
    if(![string]::IsNullOrEmpty($deploymentGroupId) -and ![string]::IsNullOrEmpty($projectId))
    {
        $restCallUrl = $tfsUrl + ("/{0}/_apis/distributedtask/deploymentgroups/{1}?api-version={2}" -f $projectId, $deploymentGroupId, $apiVersion)
        WriteAgentSettingsHelperLog "`t`t REST call Url -  $restCallUrl"
        
        return (InvokeRestURlToGetDeploymentGroupData -restCallUrl $restCallUrl -patToken $patToken)
    }

    return $null
}

 function InvokeRestURlToGetDeploymentGroupData
 {
    Param(
    [Parameter(Mandatory=$true)]
    [string]$restCallUrl,
    [Parameter(Mandatory=$false)]
    [string]$patToken
    )
    
    WriteAgentSettingsHelperLog "`t`t Invoke-rest call for deployment group data"
    $headers = Get-RESTCallHeader -patToken $patToken
    
    $detDeploymentGroupDataErrorMessageBlock = {
        $exception = $_
        $message = "Unable to fetch the deployment group information from AzureDevOps server: {0}"
        if($exception.Exception.Response)
        {
            $message -f "Status: $($exception.Exception.Response.StatusCode.value__)"
        }
        else
        {
            $message -f "$($exception.Exception)"
        }
        WriteAgentSettingsHelperLog $message
        return $message
    }
    
    $proxyObject = Construct-ProxyObjectForHttpRequests
    $response = Invoke-WithRetry -retryBlock {Invoke-RestMethod -Uri $restCallUrl -Method "Get" -Headers $headers @proxyObject} -actionName "Get deploymentgroup" `
                                 -retryCatchBlock {$null = (& $detDeploymentGroupDataErrorMessageBlock)} -finalCatchBlock {throw (& $detDeploymentGroupDataErrorMessageBlock)}


    WriteAgentSettingsHelperLog "`t`t Deployment Group Details fetched successfully"
    return $response
 }
 

function WriteAgentSettingsHelperLog
{
    param(
    [string]$logMessage
    )
    
    Write-Log ("[Agent Settings Helper]: " + $logMessage)
}

function GetAgentSettingFilePath
{
    param(
    [string]$workingFolder
    )

    $agentSettingFile = Join-Path $workingFolder $agentSetting
    WriteAgentSettingsHelperLog "`t`t Agent setting file path $agentSettingFile"  
    
    return $agentSettingFile
}
