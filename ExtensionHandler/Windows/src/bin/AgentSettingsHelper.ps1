$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\Constants.ps1"

function Test-ConfiguredAgentExists
{
    param(
        [Parameter(Mandatory=$true)]
        [string]$workingFolder,
        [scriptblock]$logFunction
    )

    try
    {
        WriteLog "Check if any existing agent is running from $workingFolder" $logFunction
    
        $agentSettingFileExist = Test-Path $(GetAgentSettingFilePath $workingFolder)
        WriteLog "`t`t Agent setting file exist: $agentSettingFileExist" $logFunction
    
        return $agentSettingFileExist 
    }
    catch
    {  
        WriteLog $_.Exception
        throw $_.Exception
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
        [string]$patToken,
        [scriptblock]$logFunction
    )

    try
    {
        WriteLog "AgentReConfigurationRequired check started." $logFunction
        
        $agentSettingFile = GetAgentSettingFilePath $workingFolder        

        if( !(Test-Path $agentSettingFile) )
        {
            WriteLog "`t`t Agent setting file $agentSettingFile does not exist" $logFunction
            return $true
        }
        WriteLog "`t`tReading agent setting file - $agentSettingFile" $logFunction
        
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
            
            WriteLog "`t`tCall GetDeploymentGroupDataFromAgentSetting" $logFunction
            $deploymentGroupDataAsPerSetting = GetDeploymentGroupDataFromAgentSetting -agentSetting $agentSetting -tfsUrl $agentUrl -patToken $patToken -logFunction $logFunction
        }
        catch
        {
            $errorMsg = $_.Exception.Message.ToString()
            WriteLog "`t`t`t Unable to get the deployment group data - $errorMsg" $logFunction
        }

        $tfsUrl = if ($tfsUrl.StartsWith($agentUrl, "CurrentCultureIgnoreCase")) {$agentUrl} else {$tfsUrl}

        if(!$deploymentGroupDataAsPerSetting)
        {
            WriteLog "`t`t`t Test-AgentSettingsAreSame Return : false (Unable to get the deployment group data from existing agent settings)" $logFunction
            return $false;
        }
        
        WriteLog "`t`t`t Agent Configured With `t`t`t`t`t Agent Need To Be Configured With" $logFunction
        WriteLog "`t`t`t $agentUrl `t`t`t`t`t $tfsUrl" $logFunction
        WriteLog "`t`t`t $($deploymentGroupDataAsPerSetting.project.name) `t`t`t`t`t $projectName" $logFunction
        WriteLog "`t`t`t $($deploymentGroupDataAsPerSetting.name) `t`t`t`t`t $deploymentGroupName" $logFunction
        if( ([string]::Compare($tfsUrl, $agentUrl, $True) -eq 0) -and ([string]::Compare($projectName, $($deploymentGroupDataAsPerSetting.project.name), $True) -eq 0) -and ([string]::Compare($deploymentGroupName, $($deploymentGroupDataAsPerSetting.name), $True) -eq 0) )
        {
            WriteLog "`t`t`t Test-AgentSettingsAreSame Return : true" $logFunction        
            return $true
        }
        WriteLog "`t`t`t Test-AgentSettingsAreSame Return : false" $logFunction        
        return $false
    }
    catch
    {  
        WriteLog $_.Exception
        throw $_.Exception
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
    [string]$patToken,
    [scriptblock]$logFunction
    )
    
    $projectId = $($agentSetting.projectId)
    $deploymentGroupId = $($agentSetting.deploymentGroupId)
    WriteLog "`t`t` Project id, Deployment group id -  $projectId, $deploymentGroupId" -logFunction $logFunction
    
    if(![string]::IsNullOrEmpty($deploymentGroupId) -and ![string]::IsNullOrEmpty($projectId))
    {
        $restCallUrl = $tfsUrl + ("/{0}/_apis/distributedtask/deploymentgroups/{1}" -f $projectId, $deploymentGroupId)
        WriteLog "`t`t REST call Url -  $restCallUrl" $logFunction
        
        return (InvokeRestURlToGetDeploymentGroupData -restCallUrl $restCallUrl -patToken $patToken -logFunction $logFunction)
    }

    return $null
}

 function InvokeRestURlToGetDeploymentGroupData
 {
    Param(
    [Parameter(Mandatory=$true)]
    [string]$restCallUrl,
    [Parameter(Mandatory=$false)]
    [string]$patToken,
    [scriptblock]$logFunction
    )
    
    WriteLog "`t`t Form the header for invoking the rest call" $logFunction
 
    $headers = Get-RESTCallHeader $patToken
    
    WriteLog "`t`t Invoke-rest call for deployment group name" $logFunction
    try
    {
        $response = Invoke-RestMethod -Uri $($restCallUrl) -headers $headers -Method Get -ContentType "application/json"
        WriteLog "`t`t Deployment Group Details fetched successfully" $logFunction
    }
    catch
    {
        throw "Unable to fetch the deployment group information from VSTS server: $($_.Exception.Response.StatusCode.value__) $($_.Exception.Response.StatusDescription)"
    }
    return $response
 }
 

function WriteLog
{
    param(
    [string]$logMessage,
    [scriptblock]$logFunction
    )
    
    $log = "[Agent Checker]: " + $logMessage
    if($logFunction -ne $null)
    {
        $logFunction.Invoke($log)
    }
    else
    {
        write-verbose $log
    }
}

function GetAgentSettingFilePath
{
    param(
    [string]$workingFolder
    )

    $agentSettingFile = Join-Path $workingFolder $agentSetting
    WriteLog "`t`t Agent setting file path $agentSettingFile"  
    
    return $agentSettingFile
}
