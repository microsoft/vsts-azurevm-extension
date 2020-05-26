$currentScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$currentScriptPath\..\bin\AgentConfigurationManager.ps1"

Describe "Agent Configuration Manager Tests" {

    Context "Agent config command without windows user credentials" {

        It "should quote arguments containing spaces" {
            $expectedArgs = "--unattended --replace --auth PAT  --url `"https://acccount.visualstudio.com`" --token `"pat`" --work `"C:\work folder`" --deploymentgroup --runasservice --agent `"my agent`" --projectname `"my proj`" --deploymentgroupname `"my dg`""
            $ret = CreateConfigCmdArgs -tfsUrl "https://acccount.visualstudio.com" -patToken "pat" -workFolder "C:\work folder" -projectName "my proj" -deploymentGroupName "my dg" -agentName "my agent" -windowsLogonAccountName "" -windowsLogonPassword ""
            $ret | Should be $expectedArgs
        }
    }

    Context "Agent config command with windows user credentials" {

        It "should quote arguments containing spaces" {
            $expectedArgs = "--unattended --replace --auth PAT  --url `"https://acccount.visualstudio.com`" --token `"pat`" --work `"C:\work folder`" --deploymentgroup --runasservice --agent `"my agent`" --projectname `"my proj`" --deploymentgroupname `"my dg`" --windowsLogonAccount `"NT AUTHORITY\LOCAL SERVICE`" --windowsLogonPassword `"password`""
            $ret = CreateConfigCmdArgs -tfsUrl "https://acccount.visualstudio.com" -patToken "pat" -workFolder "C:\work folder" -projectName "my proj" -deploymentGroupName "my dg" -agentName "my agent" -windowsLogonAccountName "NT AUTHORITY\LOCAL SERVICE" -windowsLogonPassword "password"
            $ret | Should be $expectedArgs
        }
    }

    Context "Agent config command in Pipelines Agent mode" {
        It "should emit different command-line arguments when Pipelines mode is enabled" {
            $expectedArgs = "--unattended --replace --auth PAT  --url `"https://acccount.visualstudio.com`" --token `"pat`" --work `"C:\work folder`" --norestart --pool `"pool`"" 
            $ret = CreateConfigCmdArgs -tfsUrl "https://acccount.visualstudio.com" -patToken "pat" -workFolder "C:\work folder" -projectName "my proj" -deploymentGroupName "my dg" -agentName "my agent" -isPipelinesAgent $true -poolName "pool"
            $ret | Should be $expectedArgs
        }
    }
}