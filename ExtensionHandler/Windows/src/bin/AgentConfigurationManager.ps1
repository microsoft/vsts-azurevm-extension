$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\Constants.ps1"

function WriteConfigurationLog
{
    param(
    [string]$logMessage
    )
    
    Write-Log "[Configuration]: " + $logMessage
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
    param(
    [Parameter(Mandatory=$true)]
    [string]$tfsUrl,
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
    [string]$configCmdPath,
    [string]$windowsLogonAccountName,
    [string]$windowsLogonPassword
    )

    $processStartInfo = GetProcessStartInfo
    $processStartInfo.FileName = $configCmdPath
    if($global:isOnPrem){
        $collectionName = $tfsUrl.Substring($tfsUrl.LastIndexOf('/')+1, $tfsUrl.Length-$tfsUrl.LastIndexOf('/')-1)
        $tfsUrl = $tfsUrl.Substring(0,$tfsUrl.LastIndexOf('/'))
    }
    $processStartInfo.Arguments = CreateConfigCmdArgs -tfsUrl $tfsUrl -patToken $patToken -workingFolder $workingFolder `
                                 -projectName $projectName -deploymentGroupName $deploymentGroupName -agentName $agentName `
                                 -windowsLogonAccountName $windowsLogonAccountName -windowsLogonPassword $windowsLogonPassword
    if($global:isOnPrem){
        $processStartInfo.Arguments += " --collectionName $collectionName"
    }
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

function CreateConfigCmdArgs
{
    param(
        [Parameter(Mandatory=$true)]
        [string]$tfsUrl,
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
        [string]$windowsLogonAccountName,
        [string]$windowsLogonPassword
    )

    $configCmdArgs = "$configCommonArgs --agent `"$agentName`" --url `"$tfsUrl`" --token `"$patToken`" --work `"$workingFolder`" --projectname `"$projectName`" --deploymentgroupname `"$deploymentGroupName`""
    if($windowsLogonAccountName){
        $configCmdArgs += " --windowsLogonAccount `"$windowsLogonAccountName`" --windowsLogonPassword `"$windowsLogonPassword`""
    }
    return $configCmdArgs
}
