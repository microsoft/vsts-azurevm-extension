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
}

Describe "Download agent tests" {

    Context "Should set error status if exception happens" {

        Mock -ModuleName RMExtensionHandler Write-Log{}
        Mock -ModuleName RMExtensionHandler Set-HandlerErrorStatus {}
        Mock -ModuleName RMExtensionHandler Add-HandlerSubStatus {}
        Mock -ModuleName RMExtensionHandler Invoke-GetAgentScript { throw New-Object System.Exception("some error")}

        It "should call clean up functions" {
            { Get-Agent @{} } | Should Throw
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

        It "should call clean up functions" {
            { Test-AgentAlreadyExists @{} } | Should Throw
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

        It "should call clean up functions" {
            { Register-Agent @{} $true } | Should Throw
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