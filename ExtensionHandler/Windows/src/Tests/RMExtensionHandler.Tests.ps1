BeforeAll {
    Import-Module "$PSScriptRoot\..\bin\RMExtensionCommon.psm1"
    . "$PSScriptRoot\..\bin\AgentSettingsHelper.ps1"
}

Describe "remove agent tests" {
    Context "Should set proper status when agent is removed" {

        BeforeAll {

            Mock -ModuleName RMExtensionCommon Write-Log{}
            Mock -ModuleName RMExtensionCommon Add-HandlerSubStatus {}
            Mock -ModuleName RMExtensionCommon Set-HandlerStatus {}
            Mock -ModuleName RMExtensionCommon Clean-AgentWorkingFolder {}
            Mock -ModuleName RMExtensionCommon RemoveExistingAgent {}
        }

        It "should set proper status" {
            Remove-Agent @{
                AgentWorkingFolder = "AgentWorkingFolder"
                PATToken = "PATToken"
            }
            Assert-MockCalled -ModuleName RMExtensionCommon Add-HandlerSubStatus -Times 1 -ParameterFilter { $Code -eq $RM_Extension_Status.RemovedAgent.Code}
        }
    }
}