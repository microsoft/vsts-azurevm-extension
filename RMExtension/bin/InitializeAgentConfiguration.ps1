param(
    [Parameter(Mandatory=$true)]
    [string]$workingFolder,
    [scriptblock]$logFunction
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\Constants.ps1"

function WriteInitLog
{
    param(
    [string]$logMessage
    )
    
    $log = "[Initialization]: " + $logMessage
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
    $agentSettingFile = Join-Path $workingFolder $agentSetting
    WriteInitLog "`t`t Agent setting file path $agentSettingFile"  
    
    return $agentSettingFile
}

function IsConfiguredAgentExists
{
    $agentSettingFileExist = Test-Path $( GetAgentSettingFilePath )
    WriteInitLog "`t`t Agent setting file exist: $agentSettingFileExist"  
    
    return $agentSettingFileExist
}

try
{
    WriteInitLog "Initialization for deployment agent started."
    WriteInitLog "Check for available powershell version. Minimum PowerShell $minPSVersionSupported is required to run the deployment agent."

    $psVersion = $PSVersionTable.PSVersion.Major

    if( !( $psVersion -ge $minPSVersionSupported ) )
    {
        throw "Installed PowerShell version is $psVersion. Minimum required version is $minPSVersionSupported."
    }

    WriteInitLog "Check if any existing agent is running from $workingFolder"    
    $configuredAgentExists = IsConfiguredAgentExists

    if( $configuredAgentExists -eq $true )
    {
        WriteInitLog "There is a existing agent running from $workingFolder. It will be removed and configured with given new parameters"    
        WriteInitLog "`t`t Setting $agentRemovalRequiredVarName variable as true and $agentDownloadRequiredVarName variables as false"    
        Set-Variable -name $agentRemovalRequiredVarName -value $true -force -Option ReadOnly -Scope Global
        Set-Variable -name $agentDownloadRequiredVarName -value $false -force -Option ReadOnly -Scope Global
    }
    else
    {
        WriteInitLog "`t`t Setting $agentRemovalRequiredVarName variable as false and $agentDownloadRequiredVarName variables as true"    
        Set-Variable -name $agentRemovalRequiredVarName -value $false -force -Option ReadOnly -Scope Global
        Set-Variable -name $agentDownloadRequiredVarName -value $true -force -Option ReadOnly -Scope Global
    }
    
    return $returnSuccess    
}
catch
{  
    WriteInitLog $_.Exception
    throw $_.Exception
}
