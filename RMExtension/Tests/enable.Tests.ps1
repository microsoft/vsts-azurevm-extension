$currentScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path

Import-Module "$currentScriptPath\..\bin\AzureExtensionHandler.psm1"
Import-Module "$currentScriptPath\..\bin\RMExtensionStatus.psm1"
Import-Module "$currentScriptPath\..\bin\RMExtensionHandler.psm1"

Describe "Enable RM extension tests" {

    Context "Should save last sequence number file and remove disable mockup file" {
        
        Mock Start-RMExtensionHandler {}
        Mock Get-ConfigurationFromSettings { return @{} }
        Mock Test-AgentAlreadyExists {}
        Mock Get-Agent {}
        Mock Register-Agent {}
        Mock Add-HandlerSubStatus {}
        Mock Set-HandlerStatus {}
        Mock Write-Log {}
        Mock Set-LastSequenceNumber {}
        Mock Remove-ExtensionDisabledMarkup {}
        
        . ..\bin\enable.ps1

        It "should call clean up functions" {
            Assert-MockCalled Set-LastSequenceNumber -Times 1
            Assert-MockCalled Remove-ExtensionDisabledMarkup -Times 1
        }
    }

    Context "If exceptiopn happens suring agent configuration, Should not save last sequence number file or should not remove disable mockup file" {
        
        Mock Start-RMExtensionHandler {}
        Mock Get-ConfigurationFromSettings { return @{} }
        Mock Test-AgentAlreadyExists {}
        Mock Get-Agent {}
        Mock Register-Agent { throw }
        Mock Add-HandlerSubStatus {}
        Mock Set-HandlerStatus {}
        Mock Write-Log {}
        Mock Set-LastSequenceNumber {}
        Mock Remove-ExtensionDisabledMarkup {}
        
        try
        {
            . ..\bin\enable.ps1
        }
        catch {}

        It "should call clean up functions" {
            Assert-MockCalled Set-LastSequenceNumber -Times 0
            Assert-MockCalled Remove-ExtensionDisabledMarkup -Times 0
        }
    }
}