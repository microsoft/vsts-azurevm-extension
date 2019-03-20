<#
.Synopsis
   Utilities for logging.
#>

Set-StrictMode -Version latest
$ErrorActionPreference = 'stop'

#
# Hashtable containing the current log replicators, indexed by name
#
$script:logReplicators = @{}

<#
.Synopsis
    Writes the given message to the RM Extension log (currently PowerShell's verbose stream).

.Remarks
    Replicators can be added using Set-LogReplicator; Write-Log will pass along the formatted
    message to all replicators, which can then write it to other destinations.
#>
function Write-Log
{
    param(
        [Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true)]
        [AllowEmptyString()]
        [string]
        $Message,

        [Parameter(Mandatory=$false, Position=1, ValueFromPipeline=$true)]
        [bool]
        $LogToVerbose=$false
    )

    $formattedMessage = '[{0:s}] {1}' -f (Get-Date), $Message

    if($LogToVerbose) {
        Write-Verbose -Verbose "${formattedMessage}`r`n"
    }

    foreach ($replicator in $script:logReplicators.Values) {
        if ($replicator) {
            try {
                & $replicator $formattedMessage
            }
            catch {
                Write-Verbose -Verbose @"
[ERROR] Failed to invoke log replicator.
Error: $_
Replicator: $($replicator.ToString())
"@
            }
        }
    }
}

<#
.Synopsis
    Returns the requested log replicator, or $null if it is not registered
#>
function Get-LogReplicator
{
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string] $Name
    )

    $script:logReplicators[$Name]
}
<#
.Synopsis
    Sets a replicator for Write-Log; the replicator can be set to $null to unregister it.
#>
function Set-LogReplicator
{
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string] $Name,

        [Parameter(Mandatory=$true, Position=1)]
        [AllowNull()]
        [ScriptBlock] $Replicator
    )

    $script:logReplicators[$Name] = $Replicator
}

Export-ModuleMember `
    -Function `
        Get-LogReplicator,
        Set-LogReplicator,
        Write-Log
