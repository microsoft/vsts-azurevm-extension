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
        WriteLog "Initialization for deployment agent started." $logFunction
        WriteLog "Check for available powershell version. Minimum PowerShell $minPSVersionSupported is required to run the deployment agent." $logFunction

        $psVersion = $PSVersionTable.PSVersion.Major

        if( !( $psVersion -ge $minPSVersionSupported ) )
        {
            throw "Installed PowerShell version is $psVersion. Minimum required version is $minPSVersionSupported."
        }

        WriteLog "Check if any existing agent is running from $workingFolder" $logFunction
    
        $agentSettingFileExist = Test-Path $( GetAgentSettingFilePath $workingFolder)
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
        [Parameter(Mandatory=$false)]
        [bool]$isOnPrem = $false,
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
            $agentCollection = if($agentSetting.collectionName){$agentSetting.collectionName}
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

        if(!$deploymentGroupDataAsPerSetting)
        {
            WriteLog "`t`t`t Test-AgentSettingsAreSame Return : false (Unable to get the deployment group data from existing agent settings)" $logFunction
            return $false;
        }
        
        WriteLog "`t`t`t Agent Configured With `t`t`t`t`t Agent Need To Be Configured With" $logFunction
        WriteLog "`t`t`t $agentTfsUrl `t`t`t`t`t $tfsUrl" $logFunction
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
    
    $deploymenteGroupId = ""
    $projectId = ""

    try
    {
        $deploymentGroupId = $($agentSetting.deploymentGroupId)
        WriteLog "`t`t` Deployment group id -  $deploymentGroupId" -logFunction $logFunction
    }
    catch{}
    ## Back-compat for MG to DG rename.
    if([string]::IsNullOrEmpty($deploymentGroupId)) 
    {
        try
        {   
            $deploymentGroupId = $($agentSetting.machineGroupId)
            WriteLog "`t`t` Machine group id -  $deploymentGroupId" -logFunction $logFunction
        }catch{}    
    }
    
    try
    {
        $projectId = $($agentSetting.projectId)
        WriteLog "`t`t` Deployment group projectId -  $projectId" -logFunction $logFunction
    }
    catch{}
    ## Back-compat for ProjectName to ProjectId.
    if([string]::IsNullOrEmpty($projectId)) 
    {
        WriteLog "`t`t` Project Id is not available in agent settings file, try to read the project name." -logFunction $logFunction
        try
        {   
            $projectId = $($agentSetting.projectName)
            WriteLog "`t`t` Deployment group projectName -  $projectId" -logFunction $logFunction
        }
        catch
        {
            WriteLog "`t`t` Unable to gee the peoject id/name for deployment group" -logFunction $logFunction
        }
    }

    if(![string]::IsNullOrEmpty($deploymentGroupId) -and ![string]::IsNullOrEmpty($projectId))
    {
        $restCallUrl = ContructRESTCallUrl -tfsUrl $tfsUrl -projectName $projectId -deploymentGroupId $deploymentGroupId -logFunction $logFunction
        
        return (InvokeRestURlToGetDeploymentGroupData -restCallUrl $restCallUrl -patToken $patToken -logFunction $logFunction)
    }
    
    return $null
}

function ContructRESTCallUrl
 {
    Param(
    [Parameter(Mandatory=$true)]
    [string]$tfsUrl,
    [Parameter(Mandatory=$true)]
    [string]$projectName,
    [Parameter(Mandatory=$true)]
    [string]$deploymentGroupId,
    [scriptblock]$logFunction
    )

    $restCallUrl = $tfsUrl + ("/{0}/_apis/distributedtask/deploymentgroups/{1}" -f $projectName, $deploymentGroupId)
    
    WriteLog "`t`t REST call Url -  $restCallUrl" $logFunction
    
    return $restCallUrl
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
 
    $basicAuth = ("{0}:{1}" -f '', $patToken)
    $basicAuth = [System.Text.Encoding]::UTF8.GetBytes($basicAuth)
    $basicAuth = [System.Convert]::ToBase64String($basicAuth)
    $headers = @{Authorization=("Basic {0}" -f $basicAuth)}
    
    WriteLog "`t`t Invoke-rest call for deployment group name" $logFunction
    try
    {
        $response = Invoke-RestMethod -Uri $($restCallUrl) -headers $headers -Method Get -ContentType "application/json"
        WriteLog "`t`t Deployment Group Details fetched successfully" $logFunction
        if($response.PSObject.Properties.name -contains "name")
        {
            return $response
        }
        else
        {
            throw "REST call failed"
        }
    }
    catch
    {
        throw "Unable to fetch the deployment group information from VSTS server."
    }
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
