<#
.Synopsis
    Script to enable the Pipelines Agent

#>

$ErrorActionPreference = 'stop'
Set-StrictMode -Version latest

if (!(Test-Path variable:PSScriptRoot) -or !($PSScriptRoot)) { # $PSScriptRoot is not defined in 2.0
    $PSScriptRoot = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Path)
}

Import-Module $PSScriptRoot\Log.psm1

function EnablePipelinesAgent
{
    param
    (
        [Parameter(Mandatory=$true, Position=0)]
        [hashtable] $config
    )

    try 
    {
        # create the log file if it does not exist
        $logFileName = "script.log"
        if(!(Test-Path -Path $logFileName))
        {
            Set-Content -Path $logFileName -Value "EnablePipelinesAgent"
        }

        # First check if we've already executed and configured the agent
        $autologonFile = Join-Path -Path $config.AgentFolder -ChildPath ".autologon"
        $contents = Get-Content $autologonFile -ErrorAction Ignore
        if ($contents -like '*AzDevOps*')
        {
            Write-Log "Already configured.  Marking extension as successful."
            Add-HandlerSubStatus $RM_Extension_Status.RebootedPipelinesAgent.Code $RM_Extension_Status.RebootedPipelinesAgent.Message -operationName $RM_Extension_Status.RebootedPipelinesAgent.operationName
            Set-HandlerStatus $RM_Extension_Status.Enabled.Code $RM_Extension_Status.Enabled.Message -Status success
            Exit-WithCode 0
            return
        }

        try
        {
            # If we get here, this is the first time we've run.  Make sure we have the script parameters
            Verify-InputNotNull "enableScriptParameters" $config.EnableScriptParameters        
        }
        catch
        {   
            Set-ErrorStatusAndErrorExit $_ $RM_Extension_Status.ReadingSettings.operationName
            return
        }

        Add-HandlerSubStatus $RM_Extension_Status.DownloadPipelinesAgent.Code $RM_Extension_Status.DownloadPipelinesAgent.Message -operationName $RM_Extension_Status.DownloadPipelinesAgent.operationName

        if(!(Test-Path -Path $config.AgentFolder))
        {
            New-Item -ItemType directory -Path $config.AgentFolder
        }

        Write-Log "Switch to TLS 1.2 to download files"
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        Write-Log "Downloading files"
        $webclient = New-Object System.Net.WebClient

        # Download the agent zip file
        Write-Log ("Downloading agent zip file from " + $config.AgentDownloadUrl)
        Add-HandlerSubStatus $RM_Extension_Status.DownloadPipelinesZip.Code $RM_Extension_Status.DownloadPipelinesZip.Message -operationName $config.AgentDownloadUrl
        $fileName = [System.IO.Path]::GetFileName($config.AgentDownloadUrl)
        $agentZipFile = Join-Path -Path $config.AgentFolder -ChildPath $fileName
        $webclient.DownloadFile($config.AgentDownloadUrl, $agentZipFile)

        # Download the enable script
        Write-Log ("Downloading enable script from " + $config.EnableScriptDownloadUrl)
        Add-HandlerSubStatus $RM_Extension_Status.DownloadPipelinesZip.Code $RM_Extension_Status.DownloadPipelinesScript.Message -operationName $config.EnableScriptDownloadUrl
        $fileName = [System.IO.Path]::GetFileName($config.EnableScriptDownloadUrl)
        $enableFileName = Join-Path -Path $config.AgentFolder -ChildPath $fileName
        $webclient.DownloadFile($config.EnableScriptDownloadUrl, $enableFileName)
    }
    catch 
    {
        $exception = $Error[0]
        Write-Log $exception
        Add-HandlerSubStatus $RM_Extension_Status.DownloadPipelinesAgentError.Code $exception -operationName $RM_Extension_Status.DownloadPipelinesAgentError.operationName
        Set-ErrorStatusAndErrorExit $_ $RM_Extension_Status.DownloadPipelinesAgentError.operationName
        return
    }

    try
    {
        Add-HandlerSubStatus $RM_Extension_Status.EnablePipelinesAgent.Code $RM_Extension_Status.EnablePipelinesAgent.Message -operationName $enableFileName

        # run the enable script
        Write-Log "Running enable script"
        $argList = $enableFileName + " " + $config.EnableScriptParameters

        # We can't use -Wait here and instead need to poll for the powershell process to exit.
        # We want to wait for the powershell script to exit, but we don't want to wait for the process that it spawns to exit.
        # So poll ourselves.
        $process = Start-Process -FilePath PowerShell.exe -Verb RunAs -PassThru -ArgumentList $argList
        do {Start-Sleep -Milliseconds 1000}
        until ($process.HasExited)

        Write-Log "Enable script completed" 
        $log = Get-Content -Raw $logFileName
        Write-Log $log
    }
    catch 
    {
        $exception = $Error[0]
        Write-Log $exception

        Add-HandlerSubStatus $RM_Extension_Status.EnablePipelinesAgentError.Code $exception -operationName $RM_Extension_Status.EnablePipelinesAgentError.operationName
        Set-ErrorStatusAndErrorExit $_ $RM_Extension_Status.EnablePipelinesAgentError.operationName
        return
    }

    # verify the agent is configured by looking for the .agent file
    $agentConfigFile = Join-Path -Path $config.AgentFolder -ChildPath ".agent"
    if (!(Test-Path -Path $agentConfigFile))
    {
        Add-HandlerSubStatus $RM_Extension_Status.EnablePipelinesAgentError.Code $log -operationName $RM_Extension_Status.EnablePipelinesAgentError.operationName
        Set-ErrorStatusAndErrorExit $_ $RM_Extension_Status.EnablePipelinesAgentError.operationName
    }

    Add-HandlerSubStatus $RM_Extension_Status.EnablePipelinesAgentSuccess.Code $log -operationName $RM_Extension_Status.EnablePipelinesAgentSuccess.operationName
    Set-HandlerStatus $RM_Extension_Status.Enabled.Code $RM_Extension_Status.Enabled.Message -Status success
    Exit-WithCode 0
}
