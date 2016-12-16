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
        [Parameter(Mandatory=$true)]
        [AllowEmptyString()]
        [string]$collection,
        [Parameter(Mandatory=$true)]
        [string]$projectName,
        [Parameter(Mandatory=$true)]
        [string]$machineGroupName,
        [Parameter(Mandatory=$true)]
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
        
        $machineGroupNameAsPerSetting = ""
        
        try
        {
            $url = $tfsUrl
            if($collection)
            {
                $url = -join($tfsUrl, '/', $collection)
            }

            $machineGroupNameAsPerSetting = GetMachineGroupNameFromAgentSetting -agentSetting $agentSetting -tfsUrl $url -projectName $($agentSetting.projectName) -patToken $patToken -logFunction $logFunction
        }
        catch
        {
            $errorMsg = $_.Exception.Message.ToString()
            WriteLog "`t`t`t Unable to get the machine group name - $errorMsg" $logFunction
        }
        
        WriteLog "`t`t`t Agent Configured With `t`t`t`t`t Agent Need To Be Configured With" $logFunction
        WriteLog "`t`t`t $agentTfsUrl `t`t`t`t`t $tfsUrl" $logFunction
        WriteLog "`t`t`t $($agentSetting.projectName) `t`t`t`t`t $projectName" $logFunction
        WriteLog "`t`t`t $machineGroupNameAsPerSetting `t`t`t`t`t $machineGroupName" $logFunction
        if( ([string]::Compare($tfsUrl, $agentTfsUrl, $True) -eq 0) -and ([string]::Compare($projectName, $($agentSetting.projectName), $True) -eq 0) -and ([string]::Compare($machineGroupName, $machineGroupNameAsPerSetting, $True) -eq 0) )
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

function GetMachineGroupNameFromAgentSetting
{
    param(
    [Parameter(Mandatory=$true)]
    [object]$agentSetting,
    [Parameter(Mandatory=$true)]
    [string]$tfsUrl,
    [Parameter(Mandatory=$true)]
    [string]$projectName,
    [Parameter(Mandatory=$true)]
    [string]$patToken,
    [scriptblock]$logFunction
    )
    
    $machineGroupId = ""
    ## try catch is required only for to support the back-compat scenario where machineGroupId may not be saved with agent settings
    try
    {
        $machineGroupId = $agentSetting.MachineGroupId
        WriteLog "`t`t` Machine group id -  $machineGroupId" -logFunction $logFunction
    }catch{}    
    
    if(![string]::IsNullOrEmpty($machineGroupId))
    {
        $restCallUrl = ContructRESTCallUrl -tfsUrl $tfsUrl -projectName $projectName -machineGroupId $machineGroupId -logFunction $logFunction
        
        return (InvokeRestURlToGetMachineGroupName -restCallUrl $restCallUrl -patToken $patToken -logFunction $logFunction)
    }
    
    return $($agentSetting.machineGroupName)
}

function ContructRESTCallUrl
 {
    Param(
    [Parameter(Mandatory=$true)]
    [string]$tfsUrl,
    [Parameter(Mandatory=$true)]
    [string]$projectName,
    [Parameter(Mandatory=$true)]
    [string]$machineGroupId,
    [scriptblock]$logFunction
    )

    $restCallUrl = $tfsUrl + ("/{0}/_apis/distributedtask/machinegroups/{1}" -f $projectName, $machineGroupId)
    
    WriteLog "`t`t REST call Url -  $restCallUrl" $logFunction
    
    return $restCallUrl
 }
 
 function InvokeRestURlToGetMachineGroupName
 {
    Param(
    [Parameter(Mandatory=$true)]
    [string]$restCallUrl,
    [Parameter(Mandatory=$true)]
    [string]$patToken,
    [scriptblock]$logFunction
    )
    
    WriteLog "`t`t Form the header for invoking the rest call" $logFunction
 
    $basicAuth = ("{0}:{1}" -f '', $patToken)
    $basicAuth = [System.Text.Encoding]::UTF8.GetBytes($basicAuth)
    $basicAuth = [System.Convert]::ToBase64String($basicAuth)
    $headers = @{Authorization=("Basic {0}" -f $basicAuth)}
    
    WriteLog "`t`t Invoke-rest call for machine group name" $logFunction
    try
    {
        $response = Invoke-RestMethod -Uri $($restCallUrl) -headers $headers -Method Get -ContentType "application/json"
        WriteLog "`t`t Machine Group Details : $response" $logFunction
        if($response.PSObject.Properties.name -contains "name")
        {
            return $response.Name
        }
        else
        {
            throw "REST call failed"
        }
    }
    catch
    {
        throw "Unable to fetch the machine group information from VSTS server."
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
