$currentScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$currentScriptPath\..\bin\AgentConfigurationManager.ps1"

Describe "Agent Configuration Manager Tests" {

    Context "Agent config command" {

        It "should quote arguments containing spaces" {
            $expectedArgs = "--deploymentgroup --runasservice --unattended --replace --auth PAT  --agent `"my agent`" --url `"https://acccount.visualstudio.com`" --token pat --work `"C:\work folder`" --projectname `"my proj`" --deploymentgroupname `"my dg`""
            $ret = CreateConfigCmdArgs -tfsUrl "https://acccount.visualstudio.com" -patToken "pat" -workingFolder "C:\work folder" -projectName "my proj" -deploymentGroupName "my dg" -agentName "my agent"
            $ret | Should be $expectedArgs
        }
    }
}