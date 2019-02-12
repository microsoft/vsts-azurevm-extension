$currentScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path

Import-Module "$currentScriptPath\..\bin\RMExtensionCommon.psm1"

Describe "Pre-check agent tests" {
    $config = @{
        AgentWorkingFolder = "AgentWorkingFolder"
        Tags = @()
        VSTSUrl = "VSTSUrl"
        TeamProject = "TeamProject"
        DeploymentGroup = "DeploymentGroup"
        PATToken = "PATToken"
    }
    $script:logger = {}

    Context "Should set error status if exception happens" {

        Mock Write-Log{}
        Mock Set-ErrorStatusAndErrorExit {}
        Mock Add-HandlerSubStatus {}

        Test-AgentAlreadyExists @{}

        It "should call clean up functions" {
            Assert-MockCalled Set-ErrorStatusAndErrorExit -Times 1 #-ParameterFilter { $ErrorRecord.Exception.Message -eq "some error"}
        }
    }

    Context "Should set success status if no exception happens" {

        Mock Write-Log{}
        Mock Add-HandlerSubStatus {}
        Mock Set-HandlerStatus
        
        Test-AgentAlreadyExists @{}

        It "should call clean up functions" {
            Assert-MockCalled Add-HandlerSubStatus -Times 1 -ParameterFilter { $Code -eq $RM_Extension_Status.CheckedExistingAgent.Code}
        }
    }
}

Describe "remove agent tests" {
    Context "Should set proper status when agent is removed" {

        Mock Write-Log{}
        Mock Add-HandlerSubStatus {}
        Mock Set-HandlerStatus {}
        Mock Invoke-RemoveAgentScript {}
        Mock Clean-AgentFolder {}
        Remove-Agent @{AgentWorkingFolder = "AgentWorkingFolder"}

        It "should set proper status" {
            Assert-MockCalled Add-HandlerSubStatus -Times 1 -ParameterFilter { $Code -eq $RM_Extension_Status.RemovedAgent.Code}
            Assert-MockCalled Set-HandlerStatus -Times 1 -ParameterFilter { $Code -eq $RM_Extension_Status.Uninstalling.Code}
        }
    }
}