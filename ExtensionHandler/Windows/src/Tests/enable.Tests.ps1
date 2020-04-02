$currentScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path

Import-Module "$currentScriptPath\..\bin\AzureExtensionHandler.psm1"
Import-Module "$currentScriptPath\..\bin\RMExtensionStatus.psm1"
Import-Module "$currentScriptPath\..\bin\RMExtensionCommon.psm1"
Import-Module "$currentScriptPath\..\bin\Log.psm1"
Set-Alias Enable out-null
. "$currentScriptPath\..\bin\enable.ps1"
. "$currentScriptPath\..\bin\ConfigSettingsReader.ps1"
. "$currentScriptPath\..\bin\AgentSettingsHelper.ps1"
Remove-Item Alias:Enable

Describe "Enable RM extension tests" {

        $config = @{
            Tags = @()
        }

    Context "Should save last sequence number file and remove disable mockup file" {

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
        
        Enable

        It "should call clean up functions" {
            Assert-MockCalled Set-LastSequenceNumber -Times 1
            Assert-MockCalled Test-ExtensionDisabledMarkup -Times 1
        }
    }

    Context "If exceptiopn happens during agent configuration, Should not save last sequence number file or should not remove disable mockup file" {
        
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
        
        try
        {
            Enable
        }
        catch {}

        It "should call clean up functions" {
            Assert-MockCalled Set-LastSequenceNumber -Times 0
            Assert-MockCalled Remove-ExtensionDisabledMarkup -Times 0
        }
    }
    
    Context "If existing agent is already running with same configuration, Should not call Re-Configuration again" {
        
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
        
        Enable

        It "should not call register agent or remove-agent" {
            Assert-MockCalled Get-Agent -Times 0
            Assert-MockCalled Register-Agent -Times 0
            Assert-MockCalled Remove-Agent -Times 0
            Assert-MockCalled Set-LastSequenceNumber -Times 1
        }
    }
    
    Context "If existing agent is running with different configuration, Should Call Re-Configuration again" {
        
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
        
        Enable

        It "should call remove-agent followed by register-agent" {
            Assert-MockCalled Register-Agent -Times 1
            Assert-MockCalled Get-Agent -Times 1
            Assert-MockCalled Remove-Agent -Times 1
            Assert-MockCalled Set-LastSequenceNumber -Times 1
        }
    }
    
    Context "If no existing agent is present should download the agent and call configuration" {
        
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
        
        Enable

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
        
        Enable

        It "should call remove-agent followed by register-agent" {
            Assert-MockCalled Add-AgentTags -Times 1
            Assert-MockCalled Set-LastSequenceNumber -Times 1
        }
    }
}

Describe "Start RM extension tests" {

    Context "Should clear up things properly" {
        
        Mock Add-HandlerSubStatus {}
        
        Invoke-PreValidationChecks

        It "should set handler status as Initilized" {
            Assert-MockCalled Add-HandlerSubStatus -Times 1 -ParameterFilter { $Code -eq $RM_Extension_Status.PreValidationCheckSuccess.Code}
        }
    }

    Context "Should skip enable if current seq number is same as last seq number" {
        
        $config = @{AgentWorkingFolder = "AgentWorkingFolder"}
        Mock Get-HandlerExecutionSequenceNumber { return 2 }
        Mock Get-LastSequenceNumber { return 2 }
        Mock Add-HandlerSubStatus {}
        Mock Set-HandlerStatus {}
        Mock Write-Log {}
        Mock Exit-WithCode {}
        Mock Test-ExtensionDisabledMarkup {return $false}

        Compare-SequenceNumber $config

        It "should call clean up functions" {
            Assert-MockCalled Exit-WithCode -Times 1
        }

        It "should set handler status as Initilized" {
            Assert-MockCalled Add-HandlerSubStatus -Times 1 -ParameterFilter { $Code -eq $RM_Extension_Status.SkippedInstallation.Code}
        }
    }

    Context "Should not skip enable if current seq number is same as last seq number and extension was disabled" {
        
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

        It "should call clean up functions" {
            Assert-MockCalled Exit-WithCode -Times 0
        }

        It "should set handler status as Initilized" {
            Assert-MockCalled Add-HandlerSubStatus -Times 0 -ParameterFilter { $Code -eq $RM_Extension_Status.SkippedInstallation.Code}
            Assert-MockCalled Add-HandlerSubStatus -Times 1 -ParameterFilter { $Code -eq $RM_Extension_Status.PreValidationCheckSuccess.Code}
        }
    }
}

Describe "Download agent tests" {

    Context "Should set error status if exception happens" {

        Mock Write-Log{}
        Mock Set-ErrorStatusAndErrorExit {}
        Mock Add-HandlerSubStatus {}
        Mock Invoke-GetAgentScriptAndExtractAgent { throw New-Object System.Exception("some error")}

        Get-Agent @{}

        It "should call clean up functions" {
            Assert-MockCalled Set-ErrorStatusAndErrorExit -Times 1 #-ParameterFilter { $ErrorRecord.Exception.Message -eq "some error"}
        }
    }

    Context "Should set success status if no exception happens" {

        Mock Write-Log{}
        Mock Add-HandlerSubStatus {}
        Mock Invoke-GetAgentScriptAndExtractAgent {}
        Mock Set-HandlerStatus
        
        Get-Agent @{}

        It "should call clean up functions" {
            Assert-MockCalled Add-HandlerSubStatus -Times 1 -ParameterFilter { $Code -eq $RM_Extension_Status.DownloadedDeploymentAgent.Code}
        }
    }
}

Describe "configure agent tests" {

    Context "Should set error status if exception happens" {

        Mock Write-Log{}
        Mock Set-ErrorStatusAndErrorExit {}
        Mock Add-HandlerSubStatus {}

        Register-Agent @{}

        It "should call clean up functions" {
            Assert-MockCalled Set-ErrorStatusAndErrorExit -Times 1 #-ParameterFilter { $ErrorRecord.Exception.Message -eq "some error"}
        }
    }

    Context "Should set success status if no exception happens" {

        Mock Write-Log{}
        Mock Add-HandlerSubStatus {}
        Mock Set-HandlerStatus {}
        Mock ConfigureAgent {}
        
        Register-Agent @{
            IsBYOSAgent = $false
            BYOSPool = ""
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

        It "should call clean up functions" {
            Assert-MockCalled Add-HandlerSubStatus -Times 1 -ParameterFilter { $Code -eq $RM_Extension_Status.ConfiguredDeploymentAgent.Code}
        }
    }
}

Describe "AgentReconfigurationRequired tests" {

    $config = @{
        AgentWorkingFolder = "AgentWorkingFolder"
        Tags = @()
        VSTSUrl = "VSTSUrl"
        TeamProject = "TeamProject"
        DeploymentGroup = "DeploymentGroup"
        PATToken = "PATToken"
    }

    Context "Should set error status if exception happens" {

        Mock Write-Log{}
        Mock Set-ErrorStatusAndErrorExit {}
        Mock Add-HandlerSubStatus {}
        Mock Test-ConfiguredAgentExists {return $true}
        Mock Test-AgentSettingsAreSame { throw New-Object System.Exception("some error")}

        ExecuteAgentPreCheck $config

        It "should call clean up functions" {
            Assert-MockCalled Set-ErrorStatusAndErrorExit -Times 1 #-ParameterFilter { $ErrorRecord.Exception.Message -eq "some error"}
        }
    }

    Context "Should set success status if no exception happens" {

        Mock Write-Log{}
        Mock Add-HandlerSubStatus {}
        Mock Test-AgentSettingsAreSame { return $true}
        Mock Set-HandlerStatus
        
        ExecuteAgentPreCheck $config

        It "should call clean up functions" {
            Assert-MockCalled Add-HandlerSubStatus -Times 2
        }
    }
}
