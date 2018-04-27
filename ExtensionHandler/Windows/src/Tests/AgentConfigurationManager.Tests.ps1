$currentScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$currentScriptPath\..\bin\AgentConfigurationManager.ps1"

Describe "Agent Configuration Manager Tests" {

    Context "Agent config command without windows user credentials" {

        It "should quote arguments containing spaces" {
            $expectedArgs = "--deploymentgroup --runasservice --unattended --replace --auth PAT  --agent `"my agent`" --url `"https://acccount.visualstudio.com`" --token pat --work `"C:\work folder`" --projectname `"my proj`" --deploymentgroupname `"my dg`""
            $ret = CreateConfigCmdArgs -tfsUrl "https://acccount.visualstudio.com" -patToken "pat" -workingFolder "C:\work folder" -projectName "my proj" -deploymentGroupName "my dg" -agentName "my agent" -windowsLogonAccountName "" -windowsLogonPassword ""
            $ret | Should be $expectedArgs
        }
    }

    Context "Agent config command with windows user credentials" {

        It "should quote arguments containing spaces" {
            $expectedArgs = "--deploymentgroup --runasservice --unattended --replace --auth PAT  --agent `"my agent`" --url `"https://acccount.visualstudio.com`" --token pat --work `"C:\work folder`" --projectname `"my proj`" --deploymentgroupname `"my dg`" --windowsLogonAccount `"NT AUTHORITY\LOCAL SERVICE`" --windowsLogonPassword `"password`""
            $ret = CreateConfigCmdArgs -tfsUrl "https://acccount.visualstudio.com" -patToken "pat" -workingFolder "C:\work folder" -projectName "my proj" -deploymentGroupName "my dg" -agentName "my agent" -windowsLogonAccountName "NT AUTHORITY\LOCAL SERVICE" -windowsLogonPassword "password"
            $ret | Should be $expectedArgs
        }
    }
}