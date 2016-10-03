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
        [string]$projectName,
        [Parameter(Mandatory=$true)]
        [string]$machineGroupName,
        [scriptblock]$logFunction
    )

    try
    {
        WriteLog "AgentReConfigurationRequired check started." $logFunction
        
        $agentSettingFile = GetAgentSettingFilePath $workingFolder        

        if( !(Test-Path $agentSettingFile) )
        {
            WriteLog "`t`t Agent setting file $agentSettingFile does not exist" $logFunction
            return true
        }
        WriteLog "`t`tReading agent setting file - $agentSettingFile" $logFunction
        
        $agentSetting = Get-AgentSettings $agentSettingFile
        
        $tfsUrl = $tfsUrl.TrimEnd('/')
        $agentTfsUrl = $agentSetting.serverUrl.TrimEnd('/')
        
        WriteLog "`t`t`t Agent Configured With `t`t`t`t`t Agent Need To Be Configured With" $logFunction
        WriteLog "`t`t`t $agentTfsUrl `t`t`t`t`t $tfsUrl" $logFunction
        WriteLog "`t`t`t $($agentSetting.projectName) `t`t`t`t`t $projectName" $logFunction
        WriteLog "`t`t`t $($agentSetting.machineGroupName) `t`t`t`t`t $machineGroupName" $logFunction
        if( ([string]::Compare($tfsUrl, $agentTfsUrl, $True) -eq 0) -and ([string]::Compare($projectName, $($agentSetting.projectName), $True) -eq 0) -and ([string]::Compare($machineGroupName, $($agentSetting.machineGroupName), $True) -eq 0) )
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
    
    return ( Get-Content -Path $agentSettingFile | ConvertFrom-Json )
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
