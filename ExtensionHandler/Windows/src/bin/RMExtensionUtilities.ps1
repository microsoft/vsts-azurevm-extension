<#
.Synopsis
    Generic utilities for the RM Azure extension

#>

$ErrorActionPreference = 'stop'
Set-StrictMode -Version latest

if (!(Test-Path variable:PSScriptRoot) -or !($PSScriptRoot)) { # $PSScriptRoot is not defined in 2.0
    $PSScriptRoot = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Path)
}

Import-Module $PSScriptRoot\Log.psm1

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

function Get-RESTCallHeader
{
    param(
    [Parameter(Mandatory=$false)]
    [string]$patToken
    )

    $basicAuth = ("{0}:{1}" -f '', $patToken)
    $basicAuth = [System.Text.Encoding]::UTF8.GetBytes($basicAuth)
    $basicAuth = [System.Convert]::ToBase64String($basicAuth)
    $header = @{Authorization=("Basic {0}" -f $basicAuth)}

    return $header
}

function Invoke-WithRetry
{
    param (
        [ScriptBlock] $retryBlock,
        [ScriptBlock] $retryCatchBlock,
        [ScriptBlock] $finalCatchBlock,
        [int] $retryInterval = 5,
        [int] $maxRetries = 5,
        [string] $actionName
    )

    $retryCount = 0

    do
    {
        $retryCount++
        try
        {
            $retryBlockOutput = (& $retryBlock)
            $successMessage = "retried $retryCount times"
            if($actionName)
            {
                Write-Log ($actionName + " " + $successMessage) $true
            }
            else
            {
                Write-Log $successMessage
            }
            return $retryBlockOutput
        }
        catch
        {
            if($retryCount -lt $maxRetries)
            {
                if($retryCatchBlock)
                {
                    & $retryCatchBlock
                }
            }
            else
            {
                if($finalCatchBlock)
                {
                    & $finalCatchBlock
                }
                else
                {
                    throw "Exceeded the maximum number of retries. Error: $_"
                }
            }
        }
        Start-Sleep -s $retryInterval
    }
    While ($retryCount -lt $maxRetries)   
}

function Exit-WithCode
{
    param(
    [Parameter(Mandatory=$false, Position=0)]
    [int]$exitCode
    )
    exit $exitCode
}

function Construct-ProxyObjectForHttpRequests {
    param ()

    $proxyObject = @{}
    if($proxyConfig -and ($proxyConfig.Contains("ProxyUrl")))
    {
        $proxyObject["Proxy"] = $proxyConfig["ProxyUrl"]
    }
    return $proxyObject
}

function Download-File{
    param (
        [string] $downloadUrl,
        [string] $target
    )

    $WebClient = New-Object System.Net.WebClient
    if($proxyConfig -and ($proxyConfig.Contains("ProxyUrl")))
    {
        $WebProxy = New-Object System.Net.WebProxy($proxyConfig["ProxyUrl"], $true)
        $WebClient.Proxy = $WebProxy
    }
    $WebClient.DownloadFile($downloadUrl, $target)

}

function Convert-CommandLineToken {
    param (
	    # Command line that contains the token
		[Parameter(Mandatory=$true, Position=0)]
		$commandLine,
			
		# Name of the parameter that is used to store token
		[Parameter(Mandatory=$true, Position=1)]
		$paramName,
			
		# Name of the environment variable that will be created
		[Parameter(Mandatory=$true, Position=2)]
		$envName
    )
		
    $parameters = $commandLine.split()
        foreach ($param in $parameters ) {
        if ($param -eq $paramName )
        {
            $index = $parameters.IndexOf($param)
            [System.Environment]::SetEnvironmentVariable($envName, $parameters[$index+1], [System.EnvironmentVariableTarget]::User)
            $parameters[$index+1] = $envName
        }
    }
    
    return ([system.String]::Join(" ", $parameters))
}

function DoesSystemPersistsInNet6Whitelist {
    $WindowsId = "Windows " + (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").InstallationType

    $WindowsName = $null
    $productName = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").ProductName
    if ($productName -match '^(Windows)(\sServer)?\s(?<versionNumber>[\d.]+).*$')
    {
        $WindowsName = $matches['versionNumber']
    }

    $WindowsVersion = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentBuildNumber

    $Net6SupportedOS = $null
    $net6file = $pwd.Path + "\net6.json"
    $Net6SupportedOS = (Get-Content $net6file -Raw) | ConvertFrom-Json


    foreach ($supportedOS in $Net6SupportedOS)
    {
        if($supportedOS.id -eq $WindowsId)
        {
            $supportedVersions = $supportedOS.versions

            foreach ($supportedVersion in $supportedVersions)
            {
                try {
                    if (compareOSVersion $supportedVersion.name $WindowsName -and compareOSVersion $supportedVersion.version $WindowsVersion)
                    {
                        return $true
                    }
                }
                catch {
                    try {
                        if (compareOSVersion $supportedVersion.name $WindowsName)
                        {
                            return $true
                        }
                    }
                    catch {
                        if (compareOSVersion $supportedVersion.version $WindowsVersion)
                        {
                            return $true
                        }
                    }
                }
            }
        }
    }
    return $false
}

function compareOSVersion
{
    param(
        [string]$supportedVersion,
        [string]$WindowsVersion
    )

    if ($supportedVersion -eq $WindowsVersion) # works only if there is no "+"" in version of supported OS
    {
        return $true
    }

    if ($supportedVersion[-1] -eq '+')
    {
        $sVersion = [double]($supportedVersion -replace ".$")
        $wVerson = [double]$WindowsVersion
        if ($wVerson -ge $sVersion)
        {
            return $true
        }
    }

    return $false
}