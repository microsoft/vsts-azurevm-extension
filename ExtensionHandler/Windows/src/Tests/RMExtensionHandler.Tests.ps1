$currentScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path

Import-Module "$currentScriptPath\..\bin\AzureExtensionHandler.psm1"
Import-Module "$currentScriptPath\..\bin\RMExtensionStatus.psm1"
Import-Module "$currentScriptPath\..\bin\RMExtensionHandler.psm1"

Describe "Start RM extension tests" {

    Context "Should clear up things properly" {
        
        Mock -ModuleName RMExtensionHandler Get-HandlerExecutionSequenceNumber {}
        Mock -ModuleName RMExtensionHandler Clear-StatusFile {}
        Mock -ModuleName RMExtensionHandler Clear-HandlerCache {}
        Mock -ModuleName RMExtensionHandler Clear-HandlerSubStatusMessage {}
        Mock -ModuleName RMExtensionHandler Initialize-ExtensionLogFile {}
        Mock -ModuleName RMExtensionHandler Add-HandlerSubStatus {}
        Mock -ModuleName RMExtensionHandler Set-HandlerStatus {}
        Mock -ModuleName RMExtensionHandler Write-Log {}
        
        Start-RMExtensionHandler

        It "should call clean up functions" {
            Assert-MockCalled -ModuleName RMExtensionHandler Get-HandlerExecutionSequenceNumber -Times 1
            Assert-MockCalled -ModuleName RMExtensionHandler Clear-StatusFile -Times 1
            Assert-MockCalled -ModuleName RMExtensionHandler Clear-HandlerCache -Times 1
            Assert-MockCalled -ModuleName RMExtensionHandler Clear-HandlerSubStatusMessage -Times 1
            Assert-MockCalled -ModuleName RMExtensionHandler Initialize-ExtensionLogFile -Times 1
        }

        It "should set handler status as Initilized" {
            Assert-MockCalled -ModuleName RMExtensionHandler Set-HandlerStatus -Times 1 -ParameterFilter { $Code -eq $RM_Extension_Status.Installing.Code}
            Assert-MockCalled -ModuleName RMExtensionHandler Add-HandlerSubStatus -Times 1 -ParameterFilter { $Code -eq $RM_Extension_Status.Initialized.Code}
        }
    }

    Context "Should skip enable if current seq number is same as last seq number" {
        
        Mock -ModuleName RMExtensionHandler Get-HandlerExecutionSequenceNumber { return 2 }
        Mock -ModuleName RMExtensionHandler Get-LastSequenceNumber { return 2 }
        Mock -ModuleName RMExtensionHandler Test-ExtensionDisabledMarkup { return $false }
        Mock -ModuleName RMExtensionHandler Clear-StatusFile {}
        Mock -ModuleName RMExtensionHandler Clear-HandlerCache {}
        Mock -ModuleName RMExtensionHandler Clear-HandlerSubStatusMessage {}
        Mock -ModuleName RMExtensionHandler Initialize-ExtensionLogFile {}
        Mock -ModuleName RMExtensionHandler Add-HandlerSubStatus {}
        Mock -ModuleName RMExtensionHandler Set-HandlerStatus {}
        Mock -ModuleName RMExtensionHandler Write-Log {}
        Mock -ModuleName RMExtensionHandler Exit-WithCode0 {} 
        
        Start-RMExtensionHandler

        It "should call clean up functions" {
            Assert-MockCalled -ModuleName RMExtensionHandler Exit-WithCode0 -Times 1
        }

        It "should set handler status as Initilized" {
            Assert-MockCalled -ModuleName RMExtensionHandler Add-HandlerSubStatus -Times 1 -ParameterFilter { $Code -eq $RM_Extension_Status.SkippedInstallation.Code}
        }
    }

    Context "Should not skip enable if current seq number is same as last seq number and extension was disabled" {
        
        Mock -ModuleName RMExtensionHandler Get-HandlerExecutionSequenceNumber { return 2 }
        Mock -ModuleName RMExtensionHandler Get-LastSequenceNumber { return 2 }
        Mock -ModuleName RMExtensionHandler Test-ExtensionDisabledMarkup { return $true }
        Mock -ModuleName RMExtensionHandler Clear-StatusFile {}
        Mock -ModuleName RMExtensionHandler Clear-HandlerCache {}
        Mock -ModuleName RMExtensionHandler Clear-HandlerSubStatusMessage {}
        Mock -ModuleName RMExtensionHandler Initialize-ExtensionLogFile {}
        Mock -ModuleName RMExtensionHandler Add-HandlerSubStatus {}
        Mock -ModuleName RMExtensionHandler Set-HandlerStatus {}
        Mock -ModuleName RMExtensionHandler Write-Log {}
        Mock -ModuleName RMExtensionHandler Exit-WithCode0 {} 
        
        Start-RMExtensionHandler

        It "should call clean up functions" {
            Assert-MockCalled -ModuleName RMExtensionHandler Exit-WithCode0 -Times 0
        }

        It "should set handler status as Initilized" {
            Assert-MockCalled -ModuleName RMExtensionHandler Add-HandlerSubStatus -Times 0 -ParameterFilter { $Code -eq $RM_Extension_Status.SkippedInstallation.Code}
            Assert-MockCalled -ModuleName RMExtensionHandler Add-HandlerSubStatus -Times 1 -ParameterFilter { $Code -eq $RM_Extension_Status.Initialized.Code}
        }
    }
}

Describe "Download agent tests" {

    Context "Should set error status if exception happens" {

        Mock -ModuleName RMExtensionHandler Write-Log{}
        Mock -ModuleName RMExtensionHandler Set-HandlerErrorStatus {}
        Mock -ModuleName RMExtensionHandler Add-HandlerSubStatus {}
        Mock -ModuleName RMExtensionHandler Invoke-GetAgentScript { throw New-Object System.Exception("some error")}
        Mock -ModuleName RMExtensionHandler Exit-WithCode0 {}

        Get-Agent @{}

        It "should call clean up functions" {
            Assert-MockCalled -ModuleName RMExtensionHandler Set-HandlerErrorStatus -Times 1 -ParameterFilter { $ErrorRecord.Exception.Message -eq "some error"}
        }
    }

    Context "Should set success status if no exception happens" {

        Mock -ModuleName RMExtensionHandler Write-Log{}
        Mock -ModuleName RMExtensionHandler Set-HandlerErrorStatus {}
        Mock -ModuleName RMExtensionHandler Add-HandlerSubStatus {}
        Mock -ModuleName RMExtensionHandler Invoke-GetAgentScript {}
        Mock -ModuleName RMExtensionHandler Set-HandlerStatus
        
        Get-Agent @{}

        It "should call clean up functions" {
            Assert-MockCalled -ModuleName RMExtensionHandler Add-HandlerSubStatus -Times 1 -ParameterFilter { $Code -eq $RM_Extension_Status.DownloadedDeploymentAgent.Code}
        }
    }
}

Describe "Pre-check agent tests" {

    Context "Should set error status if exception happens" {

        Mock -ModuleName RMExtensionHandler Write-Log{}
        Mock -ModuleName RMExtensionHandler Set-HandlerErrorStatus {}
        Mock -ModuleName RMExtensionHandler Add-HandlerSubStatus {}
        Mock -ModuleName RMExtensionHandler Test-AgentAlreadyExistsInternal { throw New-Object System.Exception("some error")}
        Mock -ModuleName RMExtensionHandler Exit-WithCode0 {}

        Test-AgentAlreadyExists @{}

        It "should call clean up functions" {
            Assert-MockCalled -ModuleName RMExtensionHandler Set-HandlerErrorStatus -Times 1 -ParameterFilter { $ErrorRecord.Exception.Message -eq "some error"}
        }
    }

    Context "Should set success status if no exception happens" {

        Mock -ModuleName RMExtensionHandler Write-Log{}
        Mock -ModuleName RMExtensionHandler Set-HandlerErrorStatus {}
        Mock -ModuleName RMExtensionHandler Add-HandlerSubStatus {}
        Mock -ModuleName RMExtensionHandler Test-AgentAlreadyExistsInternal {}
        Mock -ModuleName RMExtensionHandler Set-HandlerStatus
        
        Test-AgentAlreadyExists @{}

        It "should call clean up functions" {
            Assert-MockCalled -ModuleName RMExtensionHandler Add-HandlerSubStatus -Times 1 -ParameterFilter { $Code -eq $RM_Extension_Status.PreCheckedDeploymentAgent.Code}
        }
    }
}

Describe "configure agent tests" {

    Context "Should set error status if exception happens" {

        Mock -ModuleName RMExtensionHandler Write-Log{}
        Mock -ModuleName RMExtensionHandler Set-HandlerErrorStatus {}
        Mock -ModuleName RMExtensionHandler Add-HandlerSubStatus {}
        Mock -ModuleName RMExtensionHandler Invoke-ConfigureAgentScript { throw New-Object System.Exception("some error")}
        Mock -ModuleName RMExtensionHandler Exit-WithCode0 {}

        Register-Agent @{} $true

        It "should call clean up functions" {
            Assert-MockCalled -ModuleName RMExtensionHandler Set-HandlerErrorStatus -Times 1 -ParameterFilter { $ErrorRecord.Exception.Message -eq "some error"}
        }
    }

    Context "Should set success status if no exception happens" {

        Mock -ModuleName RMExtensionHandler Write-Log{}
        Mock -ModuleName RMExtensionHandler Set-HandlerErrorStatus {}
        Mock -ModuleName RMExtensionHandler Add-HandlerSubStatus {}
        Mock -ModuleName RMExtensionHandler Invoke-ConfigureAgentScript {}
        Mock -ModuleName RMExtensionHandler Set-HandlerStatus
        
        Register-Agent @{} $true

        It "should call clean up functions" {
            Assert-MockCalled -ModuleName RMExtensionHandler Add-HandlerSubStatus -Times 1 -ParameterFilter { $Code -eq $RM_Extension_Status.ConfiguredDeploymentAgent.Code}
        }
    }
}

Describe "remove agent tests" {

    Context "Should set proper status when agent is removed" {

        Mock -ModuleName RMExtensionHandler Write-Log{}
        Mock -ModuleName RMExtensionHandler Set-HandlerErrorStatus {}
        Mock -ModuleName RMExtensionHandler Add-HandlerSubStatus {}
        Mock -ModuleName RMExtensionHandler Set-HandlerStatus {}
        Mock -ModuleName RMExtensionHandler Invoke-RemoveAgentScript {}
        Remove-Agent @{}

        It "should set proper status" {
            Assert-MockCalled -ModuleName RMExtensionHandler Add-HandlerSubStatus -Times 1 -ParameterFilter { $Code -eq $RM_Extension_Status.RemovedAgent.Code}
            Assert-MockCalled -ModuleName RMExtensionHandler Set-HandlerStatus -Times 1 -ParameterFilter { $Code -eq $RM_Extension_Status.Uninstalling.Code}
        }
    }
}