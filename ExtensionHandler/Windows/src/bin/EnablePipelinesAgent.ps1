<#
.Synopsis
    Script to enable the Pipelines Agent

#>

$ErrorActionPreference = 'stop'
$MAX_RETRIES = 3
Set-StrictMode -Version latest

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

        # Download the agent zip file
        Write-Log ("Downloading agent zip file from " + $config.AgentDownloadUrl)
        Add-HandlerSubStatus $RM_Extension_Status.DownloadPipelinesZip.Code $RM_Extension_Status.DownloadPipelinesZip.Message -operationName $config.AgentDownloadUrl
        $fileName = [System.IO.Path]::GetFileName($config.AgentDownloadUrl)
        $agentZipFile = Join-Path -Path $config.AgentFolder -ChildPath $fileName
        For ($attempt=1; $attempt -lt $MAX_RETRIES+1; $attempt++){
            try{
                Download-File -downloadUrl $config.AgentDownloadUrl -target $agentZipFile
                $attempt = $MAX_RETRIES
            }
            catch{
                $exception = $Error[0]
                Write-Log "Attempt $attempt to download the agent failed"
                Write-Log $exception
                if ($attempt -eq $MAX_RETRIES){
                    Write-Log "Max retries attempt reached"
                    Set-ErrorStatusAndErrorExit $_ $RM_Extension_Status.DownloadPipelinesAgentError.operationName
                }
            }
        }

        # Download the enable script
        Write-Log ("Downloading enable script from " + $config.EnableScriptDownloadUrl)
        Add-HandlerSubStatus $RM_Extension_Status.DownloadPipelinesScript.Code $RM_Extension_Status.DownloadPipelinesScript.Message -operationName $config.EnableScriptDownloadUrl
        $fileName = [System.IO.Path]::GetFileName($config.EnableScriptDownloadUrl)
        $enableFileName = Join-Path -Path $config.AgentFolder -ChildPath $fileName
        For ($attempt=1; $attempt -lt $MAX_RETRIES+1; $attempt++){
            try{
                Download-File -downloadUrl $config.EnableScriptDownloadUrl -target $enableFileName
                $attempt = $MAX_RETRIES
            }
            catch{
                $exception = $Error[0]
                Write-Log "Attempt $attempt to download the pipeline script failed"
                Write-Log $exception
                if ($attempt -eq $MAX_RETRIES){
                    Write-Log "Max retries attempt reached"
                    Set-ErrorStatusAndErrorExit $_ $RM_Extension_Status.DownloadPipelinesAgentError.operationName
                }
            }
        }
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
        # So poll ourselves for 30 minutes.
        $process = Start-Process -FilePath PowerShell.exe -Verb RunAs -PassThru -ArgumentList $argList
        $loops = 0
        do 
        {
            $loops++
            Start-Sleep -Milliseconds 1000
        }
        until ($process.HasExited -or ($loops -gt 1800))

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
