<#
.Synopsis
    Generic utilities for the RM Azure extension

#>

$ErrorActionPreference = 'stop'
Set-StrictMode -Version latest

if (!(Test-Path variable:PSScriptRoot) -or !($PSScriptRoot)) { # $PSScriptRoot is not defined in 2.0
    $PSScriptRoot = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Path)
}

<#
.Synopsis
    Recursively walks the given object and converts any PSObjects to Hashtables
#>
function ConvertTo-Hashtable
{
    [CmdletBinding()]
    param (
        [AllowNull()]
        [AllowEmptyCollection()]
        [Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true)]
        [object] $object
    )

    if ($object -eq $null)
    {
        return $null
    }

    switch ($object.GetType()) {
        { $_.FullName -eq 'System.Management.Automation.PSCustomObject' } {
            $hashtable = @{}

            foreach ($p in $object.psobject.properties)
            {
                $hashtable[$p.Name] = ConvertTo-Hashtable $p.Value
            }

            return $hashtable
        }

        { $_.IsArray } {
            for ($i = 0; $i -lt $object.Length; $i++) {
                $object[$i] = ConvertTo-Hashtable $object[$i]
            }

            return ,$object
        }

        default {
            return $object
        }
    }
}

<#
.synopsis
    Returns a hashtable with these items:

        Version  - A System.Version object with the version of the current OS
        IsServer - True if the current OS is a server SKU
        IsX64    - True if the current architecture is 64-bit
#>
function Get-OSVersion {
    $os = Get-WmiObject Win32_OperatingSystem
    $processor = Get-WmiObject Win32_Processor | Select-Object -First 1

    # On PS/.NET 2.0, [System.Version] doesn't have a Parse method 
    if (!($os.Version -match '^(?<major>[0-9]+)\.(?<minor>[0-9]+)(\.[0-9]+)*$')) {
        throw "Invalid OS version: $($os.Version)"
    }

    @{
        Version  = ('{0}.{1}' -f [int]::Parse($matches['major']), [int]::Parse($matches['minor']))
        IsServer = $os.ProductType -ne 1 # 1 == Workstation
        IsX64    = $processor.AddressWidth -eq 64
    }
}

Export-ModuleMember `
    -Function `
            ConvertTo-Hashtable, `
            Get-OSVersion
