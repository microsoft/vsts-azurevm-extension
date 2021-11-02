BeforeAll {
    Import-Module "$PSScriptRoot\..\bin\AzureExtensionHandler.psm1"
    Import-Module "$PSScriptRoot\..\bin\RMExtensionStatus.psm1"
    Import-Module "$PSScriptRoot\..\bin\RMExtensionCommon.psm1"
    Import-Module "$PSScriptRoot\..\bin\Log.psm1"
    Set-Alias Enable out-null
    . "$PSScriptRoot\..\bin\enable.ps1"
    . "$PSScriptRoot\..\bin\ConfigSettingsReader.ps1"
    . "$PSScriptRoot\..\bin\AgentSettingsHelper.ps1"
    Remove-Item Alias:Enable
}
Describe "Enable RM extension tests" {
    BeforeAll {
        $config = @{
            Tags = @()
        }
    }

    Context "Should save last sequence number file and remove disable mockup file" {

        BeforeAll {
            Mock Initialize-ExtensionLogFile {}
            Mock Invoke-PreValidationChecks {}
            Mock Get-ConfigurationFromSettings { return $config }
            Mock Get-Agent {}
            Mock Register-Agent {}
            Mock Add-HandlerSubStatus {}
            Mock Set-HandlerStatus {}
            Mock Write-Log {}
            Mock Set-LastSequenceNumber {}
            Mock Test-ExtensionDisabledMarkup {}
            Mock Add-AgentTags {}
            Mock Confirm-InputsAreValid {}
            Mock Validate-AgentName {}
        }

        It "should call clean up functions" {
            Enable
            Assert-MockCalled Set-LastSequenceNumber -Times 1
            Assert-MockCalled Test-ExtensionDisabledMarkup -Times 1
        }
    }

    Context "If exceptiopn happens during agent configuration, Should not save last sequence number file or should not remove disable mockup file" {
        
        BeforeAll {
            Mock Initialize-ExtensionLogFile {}
            Mock Invoke-PreValidationChecks {}
            Mock Get-ConfigurationFromSettings { return $config }
            Mock Get-Agent {}
            Mock Register-Agent { throw }
            Mock Add-HandlerSubStatus {}
            Mock Set-HandlerStatus {}
            Mock Write-Log {}
            Mock Set-LastSequenceNumber {}
            Mock Remove-ExtensionDisabledMarkup {}
            Mock Add-AgentTags {}
            Mock Confirm-InputsAreValid {}
        }

        It "should call clean up functions" {
            try
            {
                Enable
            }
            catch {}
            Assert-MockCalled Set-LastSequenceNumber -Times 0
            Assert-MockCalled Remove-ExtensionDisabledMarkup -Times 0
        }
    }
    
    <#Context "If existing agent is already running with same configuration, Should not call Re-Configuration again" {
        
        BeforeAll {
            Mock Initialize-ExtensionLogFile {}
            Mock Invoke-PreValidationChecks {}
            Mock Get-ConfigurationFromSettings { return $config }
            Mock Test-ConfiguredAgentExists { return $true}
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
            Mock Confirm-InputsAreValid {}
        }

        It "should not call register agent or remove-agent" {
            Enable
            Assert-MockCalled Get-Agent -Times 0
            Assert-MockCalled Register-Agent -Times 0
            Assert-MockCalled Remove-Agent -Times 0
            Assert-MockCalled Set-LastSequenceNumber -Times 1
        }
    }
    
    Context "If existing agent is running with different configuration, Should Call Re-Configuration again" {
        
        BeforeAll {
            Mock Initialize-ExtensionLogFile {}
            Mock Invoke-PreValidationChecks {}
            Mock Get-ConfigurationFromSettings { return $config }
            Mock Test-ConfiguredAgentExists { return $true}
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
            Mock Confirm-InputsAreValid {}
            Mock Validate-AgentName {}
        }

        It "should call remove-agent followed by register-agent" {
            Enable
            Assert-MockCalled Register-Agent -Times 1
            Assert-MockCalled Get-Agent -Times 1
            Assert-MockCalled Remove-Agent -Times 1
            Assert-MockCalled Set-LastSequenceNumber -Times 1
        }
    }#>
    
    Context "If no existing agent is present should download the agent and call configuration" {
        BeforeAll {
            
            Mock Initialize-ExtensionLogFile {}
            Mock Invoke-PreValidationChecks {}
            Mock Get-ConfigurationFromSettings { return $config }
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
            Mock Confirm-InputsAreValid {}
            Mock Validate-AgentName {}
        }

        It "should call remove-agent followed by register-agent" {
            Enable
            Assert-MockCalled Register-Agent -Times 1
            Assert-MockCalled Get-Agent -Times 1
            Assert-MockCalled Remove-Agent -Times 0
            Assert-MockCalled Set-LastSequenceNumber -Times 1
        }
    }
    
    Context "If tag are provided should trigger logic of adding tags" {
        
        BeforeAll {
            $configWithTags = @{
                Tags = @("Tag1")
            }
            
            Mock Initialize-ExtensionLogFile {}
            Mock Invoke-PreValidationChecks {}
            Mock Get-ConfigurationFromSettings { return $configWithTags }
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
            Mock Confirm-InputsAreValid {}
            Mock Validate-AgentName {}
        }

        It "should call remove-agent followed by register-agent" {
            Enable
            Assert-MockCalled Add-AgentTags -Times 1
            Assert-MockCalled Set-LastSequenceNumber -Times 1
        }
    }
}

Describe "Start RM extension tests" {

    Context "Should clear up things properly" {
        
        BeforeAll {
            Mock Add-HandlerSubStatus {}
        }

        It "should set handler status as Initilized" {
            Invoke-PreValidationChecks
            Assert-MockCalled Add-HandlerSubStatus -Times 1 -ParameterFilter { $Code -eq $RM_Extension_Status.PreValidationCheckSuccess.Code}
        }
    }

    <#Context "Should skip enable if current seq number is same as last seq number" {
        
        BeforeAll {
            $config = @{AgentWorkingFolder = "AgentWorkingFolder"}
            Mock Get-HandlerExecutionSequenceNumber { return 2 }
            Mock Get-LastSequenceNumber { return 2 }
            Mock Add-HandlerSubStatus {}
            Mock Set-HandlerStatus {}
            Mock Write-Log {}
            Mock Exit-WithCode {}
            Mock Test-ExtensionDisabledMarkup {return $false}

            Compare-SequenceNumber $config
        }

        It "should call clean up functions" {
            Assert-MockCalled Exit-WithCode -Times 1
        }

        It "should set handler status as Initilized" {
            Assert-MockCalled Add-HandlerSubStatus -Times 0 -ParameterFilter { $Code -eq $RM_Extension_Status.SkippedInstallation.Code}
        }
    }

    Context "Should not skip enable if current seq number is same as last seq number and extension was disabled" {
        
        BeforeAll {
            Mock Get-HandlerExecutionSequenceNumber { return 2 }
            Mock Get-LastSequenceNumber { return 2 }
            Mock Test-ExtensionDisabledMarkup { return $true }
            Mock Clear-StatusFile {}
            Mock Clear-HandlerCache {}
            Mock Clear-HandlerSubStatusMessage {}
            Mock Add-HandlerSubStatus {}
            Mock Set-HandlerStatus {}
            Mock Write-Log {}
            Mock Exit-WithCode {}
            Mock Get-ConfigurationFromSettings {}
            Mock Test-ExtensionSettingsAreSameAsDisabledVersion {return $true}
            Mock Confirm-InputsAreValid {}

            Invoke-PreValidationChecks
        }

        It "should call clean up functions" {
            Assert-MockCalled Exit-WithCode -Times 0
        }

        It "should set handler status as Initilized" {
            Assert-MockCalled Add-HandlerSubStatus -Times 0 -ParameterFilter { $Code -eq $RM_Extension_Status.SkippedInstallation.Code}
            Assert-MockCalled Add-HandlerSubStatus -Times 1 -ParameterFilter { $Code -eq $RM_Extension_Status.PreValidationCheckSuccess.Code}
        }
    }#>
}

Describe "Download agent tests" {

    <#Context "Should set error status if exception happens" {
        BeforeAll {
            Mock Write-Log{}
            Mock Set-ErrorStatusAndErrorExit {}
            Mock Add-HandlerSubStatus {}
            Mock Invoke-GetAgentScriptAndExtractAgent { throw New-Object System.Exception("some error")}
        }

        It "should call clean up functions" {
            Get-Agent @{}
            Assert-MockCalled Set-ErrorStatusAndErrorExit -Times 1 #-ParameterFilter { $ErrorRecord.Exception.Message -eq "some error"}
        }
    }#>

    Context "Should set success status if no exception happens" {
        BeforeAll {
            Mock Write-Log{}
            Mock Add-HandlerSubStatus {}
            Mock Invoke-GetAgentScriptAndExtractAgent {}
            Mock Set-HandlerStatus
        }

        It "should call clean up functions" {
            Get-Agent @{}
            Assert-MockCalled Add-HandlerSubStatus -Times 1 -ParameterFilter { $Code -eq $RM_Extension_Status.DownloadedDeploymentAgent.Code}
        }
    }
}

Describe "configure agent tests" {

    <#Context "Should set error status if exception happens" {

        BeforeAll {
            Mock Write-Log{}
            Mock Set-ErrorStatusAndErrorExit {}
            Mock Add-HandlerSubStatus {}
        }

        It "should call clean up functions" {
            Register-Agent @{}
            Assert-MockCalled Set-ErrorStatusAndErrorExit -Times 1 #-ParameterFilter { $ErrorRecord.Exception.Message -eq "some error"}
        }
    }#>

    Context "Should set success status if no exception happens" {
        BeforeAll {
            Mock Write-Log{}
            Mock Add-HandlerSubStatus {}
            Mock Set-HandlerStatus {}
            Mock ConfigureAgent {}
        }

        It "should call clean up functions" {
            Register-Agent @{
                AgentWorkingFolder = "AgentWorkingFolder"
                VSTSUrl = "VSTSUrl"
                PATToken = "PATToken"
                TeamProject = "TeamProject"
                DeploymentGroup = "DeploymentGroup"
                DeploymentGroupId = "DeploymentGroupId"
                AgentName = "AgentName"
                WindowsLogonAccountName = "WindowsLogonAccountName"
                WindowsLogonPassword = "WindowsLogonPassword"
            }
            Assert-MockCalled Add-HandlerSubStatus -Times 1 -ParameterFilter { $Code -eq $RM_Extension_Status.ConfiguredDeploymentAgent.Code}
        }
    }
}

Describe "AgentReconfigurationRequired tests" {

    BeforeAll {
        $config = @{
            AgentWorkingFolder = "AgentWorkingFolder"
            Tags = @()
            VSTSUrl = "VSTSUrl"
            TeamProject = "TeamProject"
            DeploymentGroup = "DeploymentGroup"
            PATToken = "PATToken"
        }
    }

    <#Context "Should set error status if exception happens" {

        BeforeAll {

            Mock Write-Log{}
            Mock Set-ErrorStatusAndErrorExit {}
            Mock Add-HandlerSubStatus {}
            Mock Test-ConfiguredAgentExists {return $true}
            Mock Test-AgentSettingsAreSame { throw New-Object System.Exception("some error")}
        }

        It "should call clean up functions" {
            ExecuteAgentPreCheck $config
            Assert-MockCalled Set-ErrorStatusAndErrorExit -Times 1 #-ParameterFilter { $ErrorRecord.Exception.Message -eq "some error"}
        }
    }#>

    Context "Should set success status if no exception happens" {

        BeforeAll {
            Mock Write-Log{}
            Mock Add-HandlerSubStatus {}
            Mock Test-AgentSettingsAreSame { return $true}
            Mock Set-HandlerStatus
        }

        It "should call clean up functions" {
            ExecuteAgentPreCheck $config
            Assert-MockCalled Add-HandlerSubStatus -Times 2
        }
    }
}
