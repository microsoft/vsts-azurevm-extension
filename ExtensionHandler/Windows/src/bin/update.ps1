<#
.Synopsis
    
#>

$ErrorActionPreference = 'stop'
Set-StrictMode -Version latest

if (!(Test-Path variable:PSScriptRoot) -or !($PSScriptRoot)) { # $PSScriptRoot is not defined in 2.0
    $PSScriptRoot = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Path)
}

Import-Module $PSScriptRoot\AzureExtensionHandler.psm1
Start-RMExtensionHandler
Set-ExtensionUpdateFile
Set-HandlerStatus $RM_Extension_Status.Updated.Code $RM_Extension_Status.Updated.Message -Status success