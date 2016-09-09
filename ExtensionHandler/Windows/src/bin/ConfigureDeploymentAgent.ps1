param(
    [Parameter(Mandatory=$true)]
    [string]$tfsUrl,
    [Parameter(Mandatory=$true)]
    [string]$patToken,
    [Parameter(Mandatory=$true)]
    [string]$projectName,
    [Parameter(Mandatory=$true)]
    [string]$machineGroupName,    
    [Parameter(Mandatory=$true)]
    [string]$workingFolder,
    [string]$agentName,
    [string]$userName,
    [boolean]$agentRemovalRequired = $false,
    [scriptblock]$logFunction    
)

$ErrorActionPreference = 'Stop'
$configCmdPath = ''

. "$PSScriptRoot\Constants.ps1"

function WriteConfigurationLog
{
    param(
    [string]$logMessage
    )
    
    $log = "[Configuration]: " + $logMessage
    if($logFunction -ne $null)
    {
        $logFunction.Invoke($log)
    }
    else
    {
        write-verbose $log
    }
}

function GetConfigCmdPath
{
     if([string]::IsNullOrEmpty($configCmdPath))
     {
        $configCmdPath = Join-Path $workingFolder $configCmd
        WriteConfigurationLog "`t`t Configuration cmd path: $configCmdPath"
     }
         
     return $configCmdPath
}

function ConfigCmdExists
{
    $configCmdExists = Test-Path $( GetConfigCmdPath )
    WriteConfigurationLog "`t`t Configuration cmd file exists: $configCmdExists"  
    
    return $configCmdExists    
}

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
    $processStartInfo = GetProcessStartInfo
    $processStartInfo.FileName = GetConfigCmdPath
    $processStartInfo.Arguments = "$configCommonArgs --agent $agentName --url $tfsUrl --pool $machineGroupName --token $patToken --work $workingFolder --projectname $projectName --machinegroupname $machineGroupName"
    
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
    $processStartInfo = GetProcessStartInfo
    $processStartInfo.FileName = GetConfigCmdPath
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

try
{
    WriteConfigurationLog "Starting the Deployment agent configuration script"
    
    if( ! $(ConfigCmdExists) )
    {
        throw "Unable to find the configuration cmd: $configCmdPath, ensure to download the agent using 'DownloadDeploymentAgent.ps1' before starting the agent configuration"
    }

    WriteConfigurationLog "Check if any existing agent running form $workingFolder"
    
    if( $agentRemovalRequired )
    {
        WriteConfigurationLog "Already a agent is running from $workingFolder, need to removing it"
        RemoveExistingAgent
    }
    else
    {
        WriteConfigurationLog "No existing agent found. Configure."        
    }
    
    if([string]::IsNullOrEmpty($agentName))
    {
        $agentName = $env:COMPUTERNAME + "-MG"
        WriteConfigurationLog "Agent name not provided, agent name will be set as $agentName"
    }
    
    
    WriteConfigurationLog "Configure agent"
    
    ConfigureAgent
    
    return $returnSuccess 
}
catch
{  
    WriteConfigurationLog $_.Exception
    throw $_.Exception
}
