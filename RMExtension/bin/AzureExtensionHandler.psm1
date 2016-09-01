<#
.Synopsis
   Utilities for managing Azure extensions

#>

$ErrorActionPreference = 'stop'
Set-StrictMode -Version latest

if (!(Test-Path variable:PSScriptRoot) -or !($PSScriptRoot)) { # $PSScriptRoot is not defined in 2.0
    $PSScriptRoot = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Path)
}

Import-Module $PSScriptRoot\RMExtensionUtilities.psm1
Import-Module $PSScriptRoot\Log.psm1

#
# Cached values
#
$script:handlerCache = $null

<#
.Synopsis
   Creates a simple circular buffer, represented as a PS object with three methods:

     * Push([object] $value) - Adds a value at the end of the buffer
     * Get() - Returns the contents of the buffer
     * Clear() - Empties the buffer
#>
function New-CircularBuffer {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
            [int] $Size
    )

    $buffer = New-Object PSObject -Property @{
        _buffer = New-Object string[] $Size
        _total  = 0
    }

    Add-Member -InputObject $buffer ScriptMethod Push {
        param([object] $value)

        $this._buffer[$this._total++ % $this._buffer.Length] = $value
    }

    Add-Member -InputObject $buffer ScriptMethod Get {
        param()

        if ($this._total -gt $this._buffer.Length)
        {
            $i = $this._total % $this._buffer.Length
            for ($count = 0; $count -lt $this._buffer.Length; $count++) {
                $this._buffer[$i++ % $this._buffer.Length] 
            }
        } else {
            for ($i = 0; $i -lt $this._total; $i++) {
                $this._buffer[$i]
            }
        }
    }

    Add-Member -InputObject $buffer ScriptMethod Clear {
        param()

        $this._total = 0
    }

    $buffer
}

#
# Circular buffer for the substatus channels
#
$script:extensionSubStatusBuffer = New-CircularBuffer -Size 40
$script:extensionLogBuffer = New-CircularBuffer -Size 1000

# log file
$script:logFilePath = ""

<#
.Synopsis
   Clears the values cached by the Get-* functions
#>
function Clear-HandlerCache
{
    [CmdletBinding()]
    param
    ()

    $script:handlerCache = @{
        getHandlerEnvironment = $null
        getHandlerExecutionSequenceNumber = $null
        getHandlerSettings = $null
    }
}

Clear-HandlerCache # call the function once to initialize the cache

<#
.Synopsis
    Returns the environment of the current Azure Extension Handler

.Outputs
    The handler environment, deserialized as a PSCustomObject

.Notes
    This function caches its return value; this is OK, since this value does not change during a particular 
    execution of the handler. Use the -Refresh argument to clear the cached value and read a new value; this
    may be useful, for example, for unit tests that need to execute this function multiple times using 
    different configurations.
#>
function Get-HandlerEnvironment
{
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param([switch] $Refresh)

    if ($script:handlerCache.getHandlerEnvironment -eq $null -or $Refresh)
    {
        $handlerEnvironmentFile = "$PSScriptRoot\..\HandlerEnvironment.json"

        #
        # The Azure documentation warns about this:
        #
        # Errors while reading HandlerEnvironment.json - In rare cases a handler might encounter errors when trying to read the 
        # HandlerEnvironment.json file, since the Azure Agent might be writing the file at the same time as well. The handler 
        # should be capable of handling such errors. Our recommendation for handler publishers would be to have a retry logic 
        # with some sort of backoff. 
        #
        $handlerEnvironmentFileContent = $null
        
        for ($sleepPeriod = 1; $sleepPeriod -le 64; $sleepPeriod = 2 * $sleepPeriod) {
            try
            {
                $handlerEnvironmentFileContent = Read-HandlerEnvironmentFile $handlerEnvironmentFile

                if (!$handlerEnvironmentFileContent) {
                    throw "$handlerEnvironmentFile is empty"
                }
                
                break
            }
            catch
            {
                Write-Log "Error reading handler environment (will retry): $_"
                Start-Sleep -Seconds $sleepPeriod
            }
        }

        if (!$handlerEnvironmentFileContent) {
            throw "Error initializing the extension: Cannot read $handlerEnvironmentFile"
        }

        $script:handlerCache.getHandlerEnvironment = $handlerEnvironmentFileContent[0].handlerEnvironment
    }

    $script:handlerCache.getHandlerEnvironment
}

<#
.Synopsis
    Gets the sequence number for the current execution of the extension handler.

.Description
    The Azure Agent writes the settings provided by the user to a file named <SequenceNumber>.settings 
    under the configFolder. Every time the user provides new settings (using the Set-AzureVM*Extension
    cmdlets) the SequenceNumber is incremented a new settings file is created.
    
    Extension handlers use the SequenceNumber to distinguish different execution instances of the handler;
    for example, handlers report status for a specific execution to a file named <SequenceNumber>.status.

.Notes
    This function caches its return value; this is OK, since this value does not change during a particular 
    execution of the handler. Use the -Refresh argument to clear the cached value and read a new value; this
    may be useful, for example, for unit tests that need to execute this function multiple times using 
    different configurations.
#>
function Get-HandlerExecutionSequenceNumber
{
    [CmdletBinding()]
    [OutputType([int])]
    param([switch] $Refresh)

    if ($script:handlerCache.getHandlerExecutionSequenceNumber -eq $null -or $Refresh)
    {
        $handlerEnvironment = Get-HandlerEnvironment -Refresh:$Refresh.IsPresent

        $settingsFilePattern = Join-Path $handlerEnvironment.configFolder '*.settings'

        $settingsFiles = dir $settingsFilePattern

        if (!$settingsFiles)
        {
            throw "Did not find any files that match $settingsFilePattern"
        }

        $script:handlerCache.getHandlerExecutionSequenceNumber = $settingsFiles | foreach { [int] $_.BaseName } | sort -Descending | select -First 1
    }
    
    $script:handlerCache.getHandlerExecutionSequenceNumber
}

<#
.Synopsis
   Returns the settings provided by the user

.Outputs
    The handler settings are deserialized as a PSCustomObject. The custom object includes an extra property,
    'sequenceNumber', indicating the sequence number of the settings file used to extract the settings
    (settings files are named "<sequenceNumber>.status").

.Notes
    This function caches its return value; this is OK, since this value does not change during a particular 
    execution of the handler. Use the -Refresh argument to clear the cached value and read a new value; this
    may be useful, for example, for unit tests that need to execute this function multiple times using 
    different configurations.
#>
function Get-HandlerSettings
{
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param([switch] $Refresh)

    if ($script:handlerCache.getHandlerSettings -eq $null -or $Refresh)
    {
        $handlerEnvironment = Get-HandlerEnvironment -Refresh:$Refresh.IsPresent
        
        $sequenceNumber = Get-HandlerExecutionSequenceNumber -Refresh:$Refresh.IsPresent

        $handlerSettingsFile = '{0}\{1}.settings' -f $handlerEnvironment.configFolder, $sequenceNumber

        Write-Log "Reading handler settings from $handlerSettingsFile"

        $settings = (Get-JsonContent $handlerSettingsFile).runtimeSettings[0].handlerSettings 

        $settings['sequenceNumber'] = $sequenceNumber

        #
        # Visual Studio calls the extension without protected settings; add them here if needed
        #
        if (!($settings.ContainsKey('protectedSettings')))
        {
            $settings['protectedSettings'] = ''
        }

        if (!($settings.ContainsKey('protectedSettingsCertThumbprint')))
        {
            $settings['protectedSettingsCertThumbprint'] = ''
        }

        #
        # If the protected settings are present then decrypt them and override them with the decrypted value
        #
        if ($settings.protectedSettings)
        {
            $protectedSettings = $settings.protectedSettings

            Write-Log "Found protected settings on Azure VM. Decrypting with certificate."
                
            $thumbprint = $settings.protectedSettingsCertThumbprint
    
            $certificate = Get-ChildItem "Cert:\LocalMachine\My\$thumbprint" -ErrorAction SilentlyContinue

            if (!$certificate)
            {
                throw 'Cannot find the encryption certificate for protected settings'
            }
                
            Add-Type -AssemblyName System.Security
                
            $envelope = New-Object System.Security.Cryptography.Pkcs.EnvelopedCms
            $envelope.Decode([Convert]::FromBase64String($protectedSettings))
            $certificateCollection = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2Collection($certificate)
            $envelope.Decrypt($certificateCollection)
            $decryptedProtectedSettings = [System.Text.Encoding]::UTF8.GetString($envelope.ContentInfo.Content)
            
            $settings.protectedSettings = ConvertTo-HashtableFromJson $decryptedProtectedSettings
        }

        $script:handlerCache.getHandlerSettings = $settings
    }

    $script:handlerCache.getHandlerSettings
}

<#
.Synopsis
    Adds a message to the substatus buffer
.Remarks
    The substatus is kept in a circular buffer and is added to the status file when Set-HandlerStatus is called
#>
function Add-HandlerSubStatusMessage
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string] $Message
    )

    $script:extensionSubStatusBuffer.Push($Message)
}

<#
.Synopsis
    Clears the substatus buffer
#>
function Clear-HandlerSubStatusMessage
{
    [CmdletBinding()]
    param()

    $script:extensionSubStatusBuffer.Clear()
}

<#
.Synopsis
    Sets the status of the extension handler
.Description
    Status is reported to a file name <SequenceNumber>.status under the path given by statusFolder in
    the handler's environment.

    These files have the following format:

    [{
        "version": 1.0,
        "timestampUTC": "2013-11-17T16:05:14Z",
        "status" : {
            "status": "<transitioning | error | success | warning>",
            "code" : 0,
            "configurationAppliedTime": "2013-11-17T16:05:14Z",
            "formattedMessage": {
                "Lang": "en-us",
                "Message": "Enable IIS on the VM."
            },
        }
    }]
.Notes
    The existing sub-status list is maintained when setting new handler status. The new sub-statuses are appended to the exisiting list.
    This is to ensure that final sub-status list contains all intermediate sub-status
#>
function Set-HandlerStatus
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, position=1)]
        [int] $Code,

        [Parameter(Mandatory=$true,Position=2)]
        [string] $Message,

        [Parameter()]
        [ValidateSet('transitioning', 'error', 'success', 'warning')]
        [string] $Status = 'transitioning'
    )

    $statusFile = '{0}\{1}.status' -f (Get-HandlerEnvironment).statusFolder, (Get-HandlerExecutionSequenceNumber)

    Write-Log ("Settings handler status to '{0}' ({1})" -f $Status, $statusFile)

    $timestampUTC = [DateTimeOffset]::Now.ToString('u')

    [System.Collections.ArrayList]$subStatusList = ((Get-HandlerStatus).status).substatus

    $statusObject = @(
        @{  
            status = @{ 
                formattedMessage = @{
                    lang = 'en-US'
                    message = $Message
                }
                status = $Status
                code = $Code
                configurationAppliedTime = $timestampUTC
                substatus = $subStatusList
            }
            version = '1.0'
            timestampUTC = $timestampUTC
        }
    )

    #This will error out when azure agent is reading it while we try to access the file 
    #Add retries if the process cannot access the status file
    $result = $false
    for ($sleepPeriod = 1; $sleepPeriod -le 64; $sleepPeriod = 2 * $sleepPeriod) 
    {
        try
        {
            Set-JsonContent -Path $statusFile -Value $statusObject -Force
            $result = $true
            break
        }
        catch
        {
            Write-Log "Error accessing the status file: $statusFile... $_"
            Write-Log "Retry after $sleepPeriod Secs..."
            Start-Sleep -Seconds $sleepPeriod
        }
    }

    if (!$result) {
        throw "Error accessing the status file: $statusFile..."
    }

    Flush-BufferToFile -buffer $script:extensionLogBuffer -logFile $script:logFilePath -Force
}

<#
.Synopsis
    Adds a sub-status to list of sub-status under status
.Description
    The existing sub-status list is maintained when setting new handler status. The new sub-statuses are appended to the exisiting list.
    This is to ensure that final sub-status list contains all intermediate sub-status
#>
function Add-HandlerSubStatus
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, position=1)]
        [int] $Code,

        [Parameter(Mandatory=$true,Position=2)]
        [string] $Message,

        [Parameter()]
        [string] $operationName,

        [Parameter()]
        [ValidateSet('transitioning', 'error', 'success', 'warning')]
        [string] $SubStatus = 'success'
    )

    $statusFile = '{0}\{1}.status' -f (Get-HandlerEnvironment).statusFolder, (Get-HandlerExecutionSequenceNumber)

    #$timestampUTC = [DateTimeOffset]::Now.ToString('u')

    $statusObject = ,(Get-HandlerStatus)

    # Get current list of sub-status
    [System.Collections.ArrayList]$subStatusList = $statusObject[0].status.substatus
    $newSubStatus = @{
            name = $operationName
            status = $SubStatus
            code = $Code
            formattedMessage = @{
                lang = 'en-US'
                message = $Message
            }
        }

    #$subStatusList = @($subStatusList, $newSubStatus)
    $subStatusList.Add($newSubStatus) > $null

    $statusObject[0].status.substatus = $subStatusList

    #$script:extensionSubStatusBuffer.Clear()

    #This will error out when azure agent is reading it while we try to access the file 
    #Add retries if the process cannot access the status file
    $result = $false
    for ($sleepPeriod = 1; $sleepPeriod -le 64; $sleepPeriod = 2 * $sleepPeriod) 
    {
        try
        {
            Set-JsonContent -Path $statusFile -Value $statusObject -Force
            $result = $true
            break
        }
        catch
        {
            Write-Log "Error accessing the status file: $statusFile... $_"
            Write-Log "Retry after $sleepPeriod Secs..."
            Start-Sleep -Seconds $sleepPeriod
        }
    }

    if (!$result) {
        throw "Error accessing the status file: $statusFile..."
    }

    Flush-BufferToFile -buffer $script:extensionLogBuffer -logFile $script:logFilePath -Force
}

<#
.Synopsis
    Gets the status of the extension handler

.Description
    Gets the status of the extension handler for the latest sequence number; use the -SequenceNumber parameter
    to change this default.

.Remarks
    Retrieves the contents of the status file, adding a SequenceNumber property
#>
function Get-HandlerStatus()
{
    [CmdletBinding()]
    param(
        [Parameter()]
        [int] $SequenceNumber = [int]::MaxValue
    )

    if ($SequenceNumber -eq [int]::MaxValue)
    {
        $SequenceNumber = Get-HandlerExecutionSequenceNumber
    }
    
    $statusFile = '{0}\{1}.status' -f (Get-HandlerEnvironment).statusFolder, $SequenceNumber

    if (!(Test-Path $statusFile))
    {
        throw "Status file for sequence number $SequenceNumber does not exist"
    }

    $status = Get-JsonContent $statusFile

    if($status -ne $null) {
        $status[0]['SequenceNumber'] = $sequenceNumber
        $status
    } else {
        @{ status = @{
            substatus = @()
            }
         }
    }
}

<#
.Synopsis
    Gets a particular channel from the status of the extension handler
#>
function Get-HandlerSubStatus()
{
    param()

    $status = Get-HandlerStatus
    $substatus = $status.status.substatus
    $substatus.formattedMessage.message
}

<#
.Synopsis
    Adds a message to the log buffer
.Remarks
    The log is kept in a circular buffer and is flushed file when Set-HandlerStatus is called
#>
function Add-HandlerLogMessage
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string] $Message
    )

    $script:extensionLogBuffer.Push($Message)
}

#
# Replicate all log output to the log file
#
Set-LogReplicator RMExtensionLog {
    param([string] $Message)

    Add-HandlerLogMessage $Message
}

<#
.Synopsis
    Converts buffer content to a string
#>
function BufferToString() 
{
    [CmdletBinding()]
    param(
        [Parameter()]
        [PSObject] $buffer
    )

    $str = New-Object System.Text.StringBuilder
    $buffer.Get() | % { $str.Append($_).Append("`r`n") > $null }
    $str.ToString().TrimEnd()
}

<#
.Synopsis
    Flushes contents of buffer to a file
#>
function Flush-BufferToFile() 
{
    [CmdletBinding()]
    param(
        [Parameter()]
        [PSObject] $buffer,

        [Parameter()]
        [string] $logFile,

        [switch]
        $Force
    )

    $str = BufferToString $script:extensionLogBuffer

    Add-Content -Encoding UTF8 -Path $logFile -Force:$Force.IsPresent -Value $str

    $script:extensionLogBuffer.Clear()
}

<#
.Synopsis
    Clears the status file. This should be used when extension is getting installed fresh and old status information has to be discarded
#>
function Clear-StatusFile()
{
    [CmdletBinding()]
    param()

    $statusFile = '{0}\{1}.status' -f (Get-HandlerEnvironment).statusFolder, (Get-HandlerExecutionSequenceNumber)

    Write-Log "Clearing status file $statusFile"
    
    Clear-Content $statusFile -Force
}

function Read-HandlerEnvironmentFile
{
    param(
        [Parameter(Mandatory=$true)]
        [string] $handlerEnvironmentFile
        )
    Get-JsonContent $handlerEnvironmentFile
}

<#
.Synopsis
    Create log file for extension. All subsequent logs will be flushed to this file.
#>
function Initialize-ExtensionLogFile()
{
    [CmdletBinding()]
    param()

    $logFilePath = '{0}\RMExtensionHandler.{1}.{2}.log' -f (Get-HandlerEnvironment).logFolder, (Get-HandlerExecutionSequenceNumber), (Get-Date -UFormat '%Y%m%d-%H%M%S')

    $script:logFilePath = $logFilePath

    New-Item $logFilePath -ItemType File > $null
}

<#
.Synopsis
    Reads a file containing a JSON object and coverts it to a PowerShell object
#>
function Get-JsonContent { 
    param(
        [Parameter(Mandatory=$true, Position=0, ValueFromPipelineByPropertyName=$true)]
        [string]
        $Path
    )
            
    $object = Get-Content $Path -Encoding UTF8 | Out-String | ConvertFrom-Json | ConvertTo-Hashtable

    if ($null -eq $object)
    {
        $object
    }
    elseif ($object.GetType().IsArray)
    {
        ,$object
    }
    else
    {
        $object
    }
}
    
<#
.Synopsis
    Takes a hashtable, array, date, number, or string, serializes it to JSON and writes it to the given file
#>
function Set-JsonContent { 
    param(
        [Parameter(Mandatory=$true, Position=0, ValueFromPipelineByPropertyName=$true)]
        [string]
        $Path,

        [Parameter(Mandatory=$true, Position=1, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [AllowNull()]
        [AllowEmptyCollection()]
        [System.Object]
        $Value,

        [switch]
        $Force
    )
            
    ConvertTo-Json -Depth 16 $Value | Set-Content -Encoding UTF8 -Path $Path -Force:$Force.IsPresent
}

<#
.Synopsis
    Serializes a hashtable to JSON
#>
function ConvertTo-JsonFromHashtable { 
    param(
        [Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true)]
        [System.Collections.Hashtable]
        $Hashtable
    )
            
    ConvertTo-Json -Depth 16 $Hashtable
}

<#
.Synopsis
    Deserializes a JSON object into a hashtable
#>
function ConvertTo-HashtableFromJson { 
    param(
        [Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true)]
        [string]
        $jsonObject
    )
            
    ConvertFrom-Json $jsonObject | ConvertTo-Hashtable
}

#
# Exports
#
Export-ModuleMember `
    -Function `
        Add-HandlerSubStatusMessage, `
        Clear-HandlerCache, `
        Clear-HandlerSubStatusMessage, `
        ConvertTo-HashtableFromJson, `
        ConvertTo-JsonFromHashtable, `
        Get-HandlerEnvironment,`
        Get-HandlerExecutionSequenceNumber,`
        Get-HandlerSettings, `
        Get-HandlerStatus, `
        Get-HandlerSubStatus, `
        Initialize-ExtensionLogFile, `
        Add-HandlerLogMessage, `
        Get-JsonContent, `
        New-CircularBuffer, `
        Set-HandlerStatus, `
        Add-HandlerSubStatus, `
        Clear-StatusFile, `
        Set-JsonContent
