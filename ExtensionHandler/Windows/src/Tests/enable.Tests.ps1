$currentScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path

Import-Module "$currentScriptPath\..\bin\AzureExtensionHandler.psm1"
Import-Module "$currentScriptPath\..\bin\RMExtensionStatus.psm1"
Import-Module "$currentScriptPath\..\bin\RMExtensionHandler.psm1"
Import-Module "$currentScriptPath\..\bin\Log.psm1"

Describe "Enable RM extension tests" {

    $config = @{
        Tags = @()
    }

    Context "Should save last sequence number file and remove disable mockup file" {

        Mock Start-RMExtensionHandler {}
        Mock Get-ConfigurationFromSettings { return $config }
        Mock Test-AgentAlreadyExists {}
        Mock Get-Agent {}
        Mock Register-Agent {}
        Mock Add-HandlerSubStatus {}
        Mock Set-HandlerStatus {}
        Mock Write-Log {}
        Mock Set-LastSequenceNumber {}
        Mock Remove-ExtensionDisabledMarkup {}
        Mock Add-AgentTags {}
        
        . ..\bin\enable.ps1

        It "should call clean up functions" {
            Assert-MockCalled Set-LastSequenceNumber -Times 1
            Assert-MockCalled Remove-ExtensionDisabledMarkup -Times 1
        }
    }

    Context "If exceptiopn happens during agent configuration, Should not save last sequence number file or should not remove disable mockup file" {
        
        Mock Start-RMExtensionHandler {}
        Mock Get-ConfigurationFromSettings { return $config }
        Mock Test-AgentAlreadyExists {}
        Mock Get-Agent {}
        Mock Register-Agent { throw }
        Mock Add-HandlerSubStatus {}
        Mock Set-HandlerStatus {}
        Mock Write-Log {}
        Mock Set-LastSequenceNumber {}
        Mock Remove-ExtensionDisabledMarkup {}
        Mock Add-AgentTags {}
        
        try {
            . ..\bin\enable.ps1
        }
        catch {
        }

        It "should call clean up functions" {
            Assert-MockCalled Set-LastSequenceNumber -Times 0
            Assert-MockCalled Remove-ExtensionDisabledMarkup -Times 0
        }
    }
    
    Context "If existing agent is already running with same configuration, Should not call Re-Configuration again" {
        
        Mock Start-RMExtensionHandler {}
        Mock Get-ConfigurationFromSettings { return $config }
        Mock Test-AgentAlreadyExists { return $true}
        Mock Test-AgentReconfigurationRequired { return $false}
        Mock Get-Agent {}
        Mock Register-Agent {}
        Mock Remove-Agent {}
        Mock Add-HandlerSubStatus {}
        Mock Set-HandlerStatus {}
        Mock Write-Log {}
        Mock Set-LastSequenceNumber {}
        Mock Remove-ExtensionDisabledMarkup {}
        Mock Add-AgentTags {}
        
        . ..\bin\enable.ps1

        It "should not call register agent or remove-agent" {
            Assert-MockCalled Get-Agent -Times 0
            Assert-MockCalled Register-Agent -Times 0
            Assert-MockCalled Remove-Agent -Times 0
            Assert-MockCalled Set-LastSequenceNumber -Times 1
        }
    }
    
    Context "If existing agent is running with different configuration, Should Call Re-Configuration again" {
        
        Mock Start-RMExtensionHandler {}
        Mock Get-ConfigurationFromSettings { return $config }
        Mock Test-AgentAlreadyExists { return $true}
        Mock Test-AgentReconfigurationRequired { return $true}
        Mock Get-Agent {}
        Mock Register-Agent {}
        Mock Remove-Agent {}
        Mock Add-HandlerSubStatus {}
        Mock Set-HandlerStatus {}
        Mock Write-Log {}
        Mock Set-LastSequenceNumber {}
        Mock Remove-ExtensionDisabledMarkup {}
        Mock Add-AgentTags {}
        
        . ..\bin\enable.ps1

        It "should call remove-agent followed by register-agent" {
            Assert-MockCalled Register-Agent -Times 1
            Assert-MockCalled Get-Agent -Times 0
            Assert-MockCalled Remove-Agent -Times 1
            Assert-MockCalled Set-LastSequenceNumber -Times 1
        }
    }
    
    Context "If no existing agent is present should download the agent and call configuration" {
        
        Mock Start-RMExtensionHandler {}
        Mock Get-ConfigurationFromSettings { return $config }
        Mock Test-AgentAlreadyExists { return $false}
        Mock Test-AgentReconfigurationRequired { return $false}
        Mock Get-Agent {}
        Mock Register-Agent {}
        Mock Remove-Agent {}
        Mock Add-HandlerSubStatus {}
        Mock Set-HandlerStatus {}
        Mock Write-Log {}
        Mock Set-LastSequenceNumber {}
        Mock Remove-ExtensionDisabledMarkup {}
        Mock Add-AgentTags {}
        
        . ..\bin\enable.ps1

        It "should call remove-agent followed by register-agent" {
            Assert-MockCalled Register-Agent -Times 1
            Assert-MockCalled Get-Agent -Times 1
            Assert-MockCalled Remove-Agent -Times 0
            Assert-MockCalled Set-LastSequenceNumber -Times 1
        }
    }
    
    Context "If tag are provided should trigger logic of adding tags" {
        
        $configWithTags = @{
            Tags = @("Tag1")
        }
        
        Mock Start-RMExtensionHandler {}
        Mock Get-ConfigurationFromSettings { return $configWithTags }
        Mock Test-AgentAlreadyExists { return $false}
        Mock Test-AgentReconfigurationRequired { return $false}
        Mock Get-Agent {}
        Mock Register-Agent {}
        Mock Remove-Agent {}
        Mock Add-HandlerSubStatus {}
        Mock Set-HandlerStatus {}
        Mock Write-Log {}
        Mock Set-LastSequenceNumber {}
        Mock Remove-ExtensionDisabledMarkup {}
        Mock Add-AgentTags {}
        
        . ..\bin\enable.ps1

        It "should call remove-agent followed by register-agent" {
            Assert-MockCalled Add-AgentTags -Times 1
            Assert-MockCalled Set-LastSequenceNumber -Times 1
        }
    }

    Context "If agent removal fails doe to unconfiguration error, should rename the agent folder and continue" {
        
        $config = @{
            AgentWorkingFolder = 'TestFolder'
            Tags = @("Tag1")
        }
        
        Mock Start-RMExtensionHandler {}
        Mock Get-ConfigurationFromSettings { return $config }
        Mock Test-AgentAlreadyExists { return $true}
        Mock Test-AgentReconfigurationRequired { return $true}
        Mock Get-Agent {}
        Mock Invoke-RemoveAgentScript {
            $exception = New-Object System.Exception("Agent removal failed ")
            $exception.Data["Reason"] = "UnConfigFailed"
            throw $exception
        }
        Mock Add-HandlerSubStatus {}
        Mock Set-HandlerStatus {}
        Mock Write-Log {}
        Mock Set-LastSequenceNumber {}
        Mock Remove-ExtensionDisabledMarkup {}
        Mock Add-AgentTags {}
        Mock Test-Path { return $true}
        Mock Get-Content { return @{
                agentName = 'TestName'
            }
        }
        Mock Rename-Item {}
        Mock Create-AgentWorkingFolder {}
        Mock Add-HandlerSubStatus {}

        . ..\bin\enable.ps1

        It "should call rename the agent folder followed by download and configure" {
            Assert-MockCalled Get-Agent -Times 1
            Assert-MockCalled Add-AgentTags -Times 1
        }
    }
}