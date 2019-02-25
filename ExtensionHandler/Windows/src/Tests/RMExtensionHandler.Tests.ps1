$currentScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path

Import-Module "$currentScriptPath\..\bin\RMExtensionCommon.psm1"
. "$currentScriptPath\..\bin\AgentSettingsHelper.ps1"

Describe "Pre-check agent tests" {
    $config = @{
        AgentWorkingFolder = "AgentWorkingFolder"
    }
    $global:logger = {}

    <#Context "Should set error status if exception happens" {

        Mock -ModuleName RMExtensionCommon Add-HandlerSubStatus {}
        Mock -ModuleName RMExtensionCommon Write-Log {}
        Mock -ModuleName RMExtensionCommon Test-ConfiguredAgentExists {
            "throwing" | Out-File .\check.txt -Append
            throw New-Object System.Exception("some error")
        }
        Mock -ModuleName RMExtensionCommon Set-ErrorStatusAndErrorExit {}

        Test-AgentAlreadyExists $config

        It "should call clean up functions" {
            Assert-MockCalled -ModuleName RMExtensionCommon Set-ErrorStatusAndErrorExit -Times 1 #-ParameterFilter { $ErrorRecord.Exception.Message -eq "some error"}
        }
    }#>

    Context "Should set success status if no exception happens" {

        Mock -ModuleName RMExtensionCommon Write-Log{}
        Mock -ModuleName RMExtensionCommon Add-HandlerSubStatus {}
        Mock -ModuleName RMExtensionCommon Test-ConfiguredAgentExists {}
        
        Test-AgentAlreadyExists $config

        It "should call clean up functions" {
            Assert-MockCalled -ModuleName RMExtensionCommon Add-HandlerSubStatus -Times 2 #-ParameterFilter { $Code -eq $RM_Extension_Status.CheckedExistingAgent.Code}
        }
    }
}

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