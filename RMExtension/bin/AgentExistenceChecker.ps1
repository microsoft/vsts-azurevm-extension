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
