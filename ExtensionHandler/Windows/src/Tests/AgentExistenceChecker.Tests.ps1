$currentScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$currentScriptPath\..\bin\AgentExistenceChecker.ps1"

Describe "Agent ExistenceChecker Tests" {

    Context "Test-ConfiguredAgentExists Should true or false as per existence of .agent file" {
        
        Mock GetAgentSettingFilePath { return "t:\nonExistingPath\.agent"}

        It "should return false if .agent file does not exist" {
            $ret = Test-ConfiguredAgentExists "c:\123"     
            $ret | Should be "$false"                 
        }

        Mock GetAgentSettingFilePath { return "$currentScriptPath\..\bin\AgentExistenceChecker.ps1"}
        
        It "should return true if .agent file does not exist" {
            $ret = Test-ConfiguredAgentExists "c:\123"     
            $ret | Should be "$true"     
        }
    }   
    
     Context "Test-AgentSettingsAreSame should work fine" {
        
        $agentSettings =  '{  "agentId": 17,  "agentName": "Agent-Name-For-Mg",  "poolId": 2,  "serverUrl": "http://mylocaltfs:8080/tfs/",  "workFolder": "_work",  "projectName": "testProj",  "machineGroupName": "my-mggrp1" }' | ConvertFrom-Json        
        
        Mock GetAgentSettingFilePath { return "$currentScriptPath\..\bin\AgentExistenceChecker.ps1"}
        Mock Get-AgentSettings { return $agentSettings }

        It "should return true if given agent settings are same as existing agent running with" {
            $ret = Test-AgentSettingsAreSame -workingFolder "c:\test" -tfsUrl "http://mylocaltfs:8080/tfs" -projectName "testProj" -machineGroupName "my-mggrp1"
            $ret | Should be "$true"                 
        }

        It "should return false if given agent settings are not same as existing agent running with ( project name different )" {
            $ret = Test-AgentSettingsAreSame -workingFolder "c:\test" -tfsUrl "http://mylocaltfs:8080/tfs" -projectName "testProjDifferentOne" -machineGroupName "my-mggrp1"
            $ret | Should be "$false"                 
        }
        
        It "should return false if given agent settings are not same as existing agent running with ( machine group name different )" {
            $ret = Test-AgentSettingsAreSame -workingFolder "c:\test" -tfsUrl "http://mylocaltfs:8080/tfs" -projectName "testProj" -machineGroupName "my-mggrp1-different"
            $ret | Should be "$false"                 
        }
        
         It "should return false if given agent settings are not same as existing agent running with ( tfs url different )" {
            $ret = Test-AgentSettingsAreSame -workingFolder "c:\test" -tfsUrl "http://mylocaltfsdifferentone:8080/tfs" -projectName "testProj" -machineGroupName "my-mggrp1"
            $ret | Should be "$false"                 
        }
    }        
}


