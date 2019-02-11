$currentScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path

Import-Module "$currentScriptPath\..\bin\RMExtensionCommon.psm1"

Describe "Pre-check agent tests" {

    Context "Should set error status if exception happens" {

        Mock -ModuleName Log Write-Log{}
        Mock -ModuleName RMExtensionStatus Set-HandlerErrorStatus {}
        Mock -ModuleName AzureExtensionHandler Add-HandlerSubStatus {}
        Mock Exit-WithCode1 {}

        Test-AgentAlreadyExists @{}

        It "should call clean up functions" {
            Assert-MockCalled Set-HandlerErrorStatus -Times 1 -ParameterFilter { $ErrorRecord.Exception.Message -eq "some error"}
        }
    }

    Context "Should set success status if no exception happens" {

        Mock -ModuleName Log Write-Log{}
        Mock -ModuleName AzureExtensionHandler Add-HandlerSubStatus {}
        Mock -ModuleName AzureExtensionHandler Set-HandlerStatus
        
        Test-AgentAlreadyExists @{}

        It "should call clean up functions" {
            Assert-MockCalled Add-HandlerSubStatus -Times 1 -ParameterFilter { $Code -eq $RM_Extension_Status.CheckedExistingAgent.Code}
        }
    }
}

Describe "remove agent tests" {
    Context "Should set proper status when agent is removed" {

        Mock -ModuleName Log Write-Log{}
        Mock -ModuleName AzureExtensionHandler Add-HandlerSubStatus {}
        Mock -ModuleName AzureExtensionHandler Set-HandlerStatus {}
        Mock Invoke-RemoveAgentScript {}
        Mock Clean-AgentFolder {}
        Remove-Agent @{AgentWorkingFolder = "AgentWorkingFolder"}

        It "should set proper status" {
            Assert-MockCalled Add-HandlerSubStatus -Times 1 -ParameterFilter { $Code -eq $RM_Extension_Status.RemovedAgent.Code}
            Assert-MockCalled Set-HandlerStatus -Times 1 -ParameterFilter { $Code -eq $RM_Extension_Status.Uninstalling.Code}
        }
    }
}