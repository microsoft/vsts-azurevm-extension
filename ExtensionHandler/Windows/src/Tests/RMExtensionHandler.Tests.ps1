$currentScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path

Import-Module "$currentScriptPath\..\bin\RMExtensionCommon.psm1"
. "$currentScriptPath\..\bin\AgentSettingsHelper.ps1"

Describe "remove agent tests" {
    Context "Should set proper status when agent is removed" {

        Mock -ModuleName RMExtensionCommon Write-Log{}
        Mock -ModuleName RMExtensionCommon Add-HandlerSubStatus {}
        Mock -ModuleName RMExtensionCommon Set-HandlerStatus {}
        Mock -ModuleName RMExtensionCommon Invoke-RemoveAgentScript {}
        Mock -ModuleName RMExtensionCommon Clean-AgentWorkingFolder {}
        Remove-Agent @{AgentWorkingFolder = "AgentWorkingFolder"}

        It "should set proper status" {
            Assert-MockCalled -ModuleName RMExtensionCommon Add-HandlerSubStatus -Times 1 -ParameterFilter { $Code -eq $RM_Extension_Status.RemovedAgent.Code}
            Assert-MockCalled -ModuleName RMExtensionCommon Set-HandlerStatus -Times 1 -ParameterFilter { $Code -eq $RM_Extension_Status.Uninstalling.Code}
        }
    }
}