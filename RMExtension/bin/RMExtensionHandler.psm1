<#
.Synopsis
   Handler for managing RM extension.
#>

$ErrorActionPreference = 'stop'
Set-StrictMode -Version latest

if (!(Test-Path variable:PSScriptRoot) -or !($PSScriptRoot)) { # $PSScriptRoot is not defined in 2.0
    $PSScriptRoot = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Path)
}

Import-Module $PSScriptRoot\AzureExtensionHandler.psm1
Import-Module $PSScriptRoot\Log.psm1
Import-Module $PSScriptRoot\RMExtensionStatus.psm1
Import-Module $PSScriptRoot\RMExtensionUtilities.psm1

<#
.Synopsis
   Initializes RM extension handler. 
    - Clears status file, handler cache and handler status message
    - defines log file to be used for diagnostic logging
    - sets up proper status and sub-status

   This should be used when extension handler is getting enabled
#>
function Start-RMExtensionHandler {
    [CmdletBinding()]
    param()

    Add-HandlerSubStatusMessage "RM Extension initialization start"
    Clear-StatusFile
    Clear-HandlerCache 
    Clear-HandlerSubStatusMessage
    Initialize-ExtensionLogFile

    Add-HandlerSubStatusMessage "RM Extension initialization complete"
    Set-HandlerStatus $RM_Extension_Status.Initialized.Code $RM_Extension_Status.Initialized.Message
}

<#
.Synopsis
   Downloads VSTS agent.
   Invokes a script to download VSTS agent package and unzip it. Provides a working directory for download script to use.
#>
function DownloadVSTSAgent {
    [CmdletBinding()]
    param(
    [Parameter(Mandatory=$true, Position=0)]
    [hashtable] $config
    )

    try 
    {
        Add-HandlerSubStatusMessage "Download VSTS agent: start"
        Write-Log "Invoking script to download VSTS agent package..."

        . $PSScriptRoot\DownloadDeploymentAgent.ps1 -tfsUrl $config.VSTSUrl -userName "" -platform $config.Platform -patToken  $config.PATToken -workingFolder $config.AgentWorkingFolder

        Add-HandlerSubStatusMessage "Download VSTS agent: complete"
        Write-Log "Done downloading VSTS agent package..."

        Set-HandlerStatus $RM_Extension_Status.DownloadedVSTSAgent.Code $RM_Extension_Status.DownloadedVSTSAgent.Message
    }
    catch 
    {
        Set-HandlerErrorStatus $_
    } 
}

<#
.Synopsis
   Configures and starts VSTS agent. 
   Invokes a cmd script to configure and start agent. Provides a working directory for this script to use.
#>
function Run-VSTSAgent {
    [CmdletBinding()]
    param(
    [Parameter(Mandatory=$true, Position=0)]
    [hashtable] $config
    )

    try 
    {
        Add-HandlerSubStatusMessage "Configure VSTS agent: start"
        Write-Log "Configuring VSTS agent..."

        #cmd.exe /c "$config.AgentWorkingFolder\config.cmd --unattended --url $config.VSTSUrl --pool $config.Pool --auth PAT --token $config.PATToken --work $config.AgentWorkingFolder --runasservice" > out.txt

        $scriptPath = $config.AgentWorkingFolder
        $url = $config.VSTSUrl
        $token = $config.PATToken
        $pool = $config.Pool

        $startInfo = New-Object System.Diagnostics.ProcessStartInfo('cmd.exe', "/c  mode con cols=256 && $scriptPath\config.cmd --unattended --url $url --pool $pool --auth PAT --token $token --work $scriptPath --runasservice 2>&1")
        $startInfo.WindowStyle = 'Hidden'
        $startInfo.RedirectStandardOutput = $True
        $startInfo.UseShellExecute = $false

        $proc = [System.Diagnostics.Process]::Start($startInfo)
        $proc.WaitForExit()
        $configLog = $proc.StandardOutput.ReadToEnd();

        Add-HandlerSubStatusMessage "Configure VSTS agent: complete"
        Write-Log "Done configuring VSTS agent"
        Write-Log "Configuration log: $configLog"

        Set-HandlerStatus $RM_Extension_Status.ConfiguredVSTSAgent.Code $RM_Extension_Status.ConfiguredVSTSAgent.Message -Status success
    }
    catch 
    {
        Set-HandlerErrorStatus $_
    } 
}

<#
.Synopsis
   Reads .settings file and generates configuration settings required for downloading and configuring agent
#>
function Get-ConfigurationFromSettings {
    [CmdletBinding()]
    param()

    $sequenceNumber = Get-HandlerExecutionSequenceNumber    
    Write-Log "Sequence Number     : $sequenceNumber"

    Write-Log "Reading config settings from file..."

    #Retrieve settings from file
    $settings = Get-HandlerSettings
    
    $publicSettings = $settings['publicSettings']
    $protectedSettings = $settings['protectedSettings']
    if (-not $publicSettings) 
    {
        $publicSettings = @{}
    }

    Write-Log "Done reading config settings from file..."
    Add-HandlerSubStatusMessage "Done Reading config settings from file"

    $osVersion = Get-OSVersion

    if (!$osVersion.IsX64)
    {
        throw New-HandlerTerminatingError $RM_Extension_Status.ArchitectureNotSupported.Code -Message $RM_Extension_Status.ArchitectureNotSupported.Message
    }

    $platform = "win7-x64"
    Write-Log "Platform: $platform"

    $vstsAccountName = $publicSettings['VSTSAccountName']
    if(-not $vstsAccountName)
    {
        $message = "VSTS account name should be specified. Please specify a valid VSTS account to which RM agent will be configured."
        throw New-HandlerTerminatingError $RM_Extension_Status.ArgumentError -Message $message 
    }

    $vstsUrl = "https://{0}.visualstudio.com" -f $vstsAccountName
    Write-Log "VSTS service URL: $vstsUrl"

    $patToken = $null
    if($protectedSettings.Contains('PATToken'))
    {
        $patToken = $protectedSettings['PATToken']
    }

    if(-not $patToken)
    {
        $patToken = $publicSettings['PATToken']
        if(-not $patToken)
        {
            $message = "PAT token should be specified. Please specify a valid PAT token which will be used to authorize calls to VSTS."
            throw New-HandlerTerminatingError $RM_Extension_Status.ArgumentError -Message $message 
        }
    }

    $poolName = $publicSettings['Pool']
    if(-not $poolName)
    {
        $message = "Agent pool should be specified. Please specify a valid agent pool for agent."
        throw New-HandlerTerminatingError $RM_Extension_Status.ArgumentError -Message $message 
    }

    Write-Log "Pool: $poolName"

    $agentWorkingFolder = "$env:SystemDrive\VSTSAgent"
    Write-Log "Working folder for VSTS agent: $agentWorkingFolder"
    if(!(Test-Path $agentWorkingFolder))
    {
        Write-Log "Working folder does not exist. Creating it..."
        New-Item -ItemType Directory $agentWorkingFolder > $null
    }

    @{
        VSTSUrl  = $vstsUrl
        PATToken = $patToken
        Platform = $platform
        Pool     = $poolName
        AgentWorkingFolder = $agentWorkingFolder
    }
}

#
# Exports
#
Export-ModuleMember `
    -Function `
        Start-RMExtensionHandler, `
        DownloadVSTSAgent, `
        Get-ConfigurationFromSettings, `
        Run-VSTSAgent
