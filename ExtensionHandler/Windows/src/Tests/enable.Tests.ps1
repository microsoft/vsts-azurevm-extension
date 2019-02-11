$currentScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path

Import-Module "$currentScriptPath\..\bin\AzureExtensionHandler.psm1"
Import-Module "$currentScriptPath\..\bin\RMExtensionStatus.psm1"
Import-Module "$currentScriptPath\..\bin\RMExtensionCommon.psm1"
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
}

Describe "Start RM extension tests" {

    Context "Should clear up things properly" {
        
        Mock -ModuleName AzureExtensionHandler Get-HandlerExecutionSequenceNumber {}
        Mock -ModuleName AzureExtensionHandler Clear-StatusFile {}
        Mock -ModuleName AzureExtensionHandler Clear-HandlerCache {}
        Mock -ModuleName AzureExtensionHandler Clear-HandlerSubStatusMessage {}
        Mock -ModuleName AzureExtensionHandler Initialize-ExtensionLogFile {}
        Mock -ModuleName AzureExtensionHandler Add-HandlerSubStatus {}
        Mock -ModuleName AzureExtensionHandler Set-HandlerStatus {}
        Mock -ModuleName AzureExtensionHandler Write-Log {}
        
        Start-RMExtensionHandler

        It "should call clean up functions" {
            Assert-MockCalled Get-HandlerExecutionSequenceNumber -Times 1
            Assert-MockCalled Clear-StatusFile -Times 1
            Assert-MockCalled Clear-HandlerCache -Times 1
            Assert-MockCalled Clear-HandlerSubStatusMessage -Times 1
            Assert-MockCalled Initialize-ExtensionLogFile -Times 1
        }

        It "should set handler status as Initilized" {
            Assert-MockCalled Set-HandlerStatus -Times 1 -ParameterFilter { $Code -eq $RM_Extension_Status.Installing.Code}
            Assert-MockCalled Add-HandlerSubStatus -Times 1 -ParameterFilter { $Code -eq $RM_Extension_Status.Initialized.Code}
        }
    }

    Context "Should skip enable if current seq number is same as last seq number" {
        
        Mock -ModuleName AzureExtensionHandler Get-HandlerExecutionSequenceNumber { return 2 }
        Mock -ModuleName AzureExtensionHandler Get-LastSequenceNumber { return 2 }
        Mock -ModuleName AzureExtensionHandler Test-ExtensionDisabledMarkup { return $false }
        Mock -ModuleName AzureExtensionHandler Clear-StatusFile {}
        Mock -ModuleName AzureExtensionHandler Clear-HandlerCache {}
        Mock -ModuleName AzureExtensionHandler Clear-HandlerSubStatusMessage {}
        Mock -ModuleName AzureExtensionHandler Initialize-ExtensionLogFile {}
        Mock -ModuleName AzureExtensionHandler Add-HandlerSubStatus {}
        Mock -ModuleName AzureExtensionHandler Set-HandlerStatus {}
        Mock -ModuleName Log Write-Log {}
        Mock Exit-WithCode0 {} 
        
        Start-RMExtensionHandler

        It "should call clean up functions" {
            Assert-MockCalled Exit-WithCode0 -Times 1
        }

        It "should set handler status as Initilized" {
            Assert-MockCalled Add-HandlerSubStatus -Times 1 -ParameterFilter { $Code -eq $RM_Extension_Status.SkippedInstallation.Code}
        }
    }

    Context "Should not skip enable if current seq number is same as last seq number and extension was disabled" {
        
        Mock -ModuleName AzureExtensionHandler Get-HandlerExecutionSequenceNumber { return 2 }
        Mock -ModuleName AzureExtensionHandler Get-LastSequenceNumber { return 2 }
        Mock -ModuleName AzureExtensionHandler Test-ExtensionDisabledMarkup { return $true }
        Mock -ModuleName AzureExtensionHandler Clear-StatusFile {}
        Mock -ModuleName AzureExtensionHandler Clear-HandlerCache {}
        Mock -ModuleName AzureExtensionHandler Clear-HandlerSubStatusMessage {}
        Mock -ModuleName AzureExtensionHandler Initialize-ExtensionLogFile {}
        Mock -ModuleName AzureExtensionHandler Add-HandlerSubStatus {}
        Mock -ModuleName AzureExtensionHandler Set-HandlerStatus {}
        Mock -ModuleName Log Write-Log {}
        Mock Exit-WithCode0 {} 
        
        Start-RMExtensionHandler

        It "should call clean up functions" {
            Assert-MockCalled Exit-WithCode0 -Times 0
        }

        It "should set handler status as Initilized" {
            Assert-MockCalled Add-HandlerSubStatus -Times 0 -ParameterFilter { $Code -eq $RM_Extension_Status.SkippedInstallation.Code}
            Assert-MockCalled Add-HandlerSubStatus -Times 1 -ParameterFilter { $Code -eq $RM_Extension_Status.Initialized.Code}
        }
    }
}

Describe "Download agent tests" {

    Context "Should set error status if exception happens" {

        Mock -ModuleName Log Write-Log{}
        Mock -ModuleName RMExtensionStatus Set-HandlerErrorStatus {}
        Mock -ModuleName AzureExtensionHandler Add-HandlerSubStatus {}
        Mock Invoke-GetAgentScriptAndExtractAgent { throw New-Object System.Exception("some error")}
        Mock Exit-WithCode1 {}

        Get-Agent @{}

        It "should call clean up functions" {
            Assert-MockCalled Set-HandlerErrorStatus -Times 1 -ParameterFilter { $ErrorRecord.Exception.Message -eq "some error"}
        }
    }

    Context "Should set success status if no exception happens" {

        Mock -ModuleName Log Write-Log{}
        Mock -ModuleName AzureExtensionHandler Add-HandlerSubStatus {}
        Mock Invoke-GetAgentScriptAndExtractAgent {}
        Mock -ModuleName AzureExtensionHandler Set-HandlerStatus
        
        Get-Agent @{}

        It "should call clean up functions" {
            Assert-MockCalled Add-HandlerSubStatus -Times 1 -ParameterFilter { $Code -eq $RM_Extension_Status.DownloadedDeploymentAgent.Code}
        }
    }
}

Describe "configure agent tests" {

    Context "Should set error status if exception happens" {

        Mock -ModuleName Log Write-Log{}
        Mock -ModuleName RMExtensionStatus Set-HandlerErrorStatus {}
        Mock -ModuleName AzureExtensionHandler Add-HandlerSubStatus {}
        Mock Invoke-ConfigureAgentScript { throw New-Object System.Exception("some error")}
        Mock Exit-WithCode1 {}

        Register-Agent @{}

        It "should call clean up functions" {
            Assert-MockCalled Set-HandlerErrorStatus -Times 1 -ParameterFilter { $ErrorRecord.Exception.Message -eq "some error"}
        }
    }

    Context "Should set success status if no exception happens" {

        Mock -ModuleName Log Write-Log{}
        Mock -ModuleName AzureExtensionHandler Add-HandlerSubStatus {}
        Mock Invoke-ConfigureAgentScript {}
        Mock -ModuleName AzureExtensionHandler Set-HandlerStatus
        
        Register-Agent @{}

        It "should call clean up functions" {
            Assert-MockCalled Add-HandlerSubStatus -Times 1 -ParameterFilter { $Code -eq $RM_Extension_Status.ConfiguredDeploymentAgent.Code}
        }
    }
}

Describe "AgentReconfigurationRequired tests" {

    Context "Should set error status if exception happens" {

        Mock -ModuleName Log Write-Log{}
        Mock -ModuleName RMExtensionStatus Set-HandlerErrorStatus {}
        Mock -ModuleName AzureExtensionHandler Add-HandlerSubStatus {}
        Mock Test-AgentReConfigurationRequiredInternal { throw New-Object System.Exception("some error")}
        Mock Exit-WithCode1 {}

        Test-AgentReconfigurationRequired @{}

        It "should call clean up functions" {
            Assert-MockCalled Set-HandlerErrorStatus -Times 1 -ParameterFilter { $ErrorRecord.Exception.Message -eq "some error"}
        }
    }

    Context "Should set success status if no exception happens" {

        Mock -ModuleName Log Write-Log{}
        Mock -ModuleName AzureExtensionHandler Add-HandlerSubStatus {}
        Mock Test-AgentReConfigurationRequiredInternal { return $true}
        Mock -ModuleName AzureExtensionHandler Set-HandlerStatus
        
        Test-AgentReconfigurationRequired @{}

        It "should call clean up functions" {
            Assert-MockCalled Add-HandlerSubStatus -Times 1 -ParameterFilter { $Code -eq $RM_Extension_Status.CheckingAgentReConfigurationRequired.Code}
        }
    }
}