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
        
        $agentSettings =  '{  "agentId": 17,  "agentName": "Agent-Name-For-Mg",  "poolId": 2,  "serverUrl": "http://mylocaltfs:8080/tfs/testColl",  "workFolder": "_work",  "projectName": "testProj",  "machineGroupName": "my-mggrp1" }' | ConvertFrom-Json        
        
        Mock GetAgentSettingFilePath { return "$currentScriptPath\..\bin\AgentExistenceChecker.ps1"}
        Mock Get-AgentSettings { return $agentSettings }
        Mock GetMachineGroupNameFromAgentSetting { return $($agentSettings.machineGroupName) }
        
        It "should return true if given agent settings are same as existing agent running with" {
            $ret = Test-AgentSettingsAreSame -workingFolder "c:\test" -tfsUrl "http://mylocaltfs:8080/tfs/testColl" -collection "" -projectName "testProj" -machineGroupName "my-mggrp1" -patToken "test-PAT"
            $ret | Should be "$true"

            Assert-MockCalled GetMachineGroupNameFromAgentSetting -Times 1 -ParameterFilter { $tfsUrl.EndsWith("/tfs/testColl") }             
        }

        It "should return false if given agent settings are not same as existing agent running with ( project name different )" {
            $ret = Test-AgentSettingsAreSame -workingFolder "c:\test" -tfsUrl "http://mylocaltfs:8080/tfs/testColl" -collection "testColl" -projectName "testProjDifferentOne" -machineGroupName "my-mggrp1" -patToken "test-PAT"
            $ret | Should be "$false"

            Assert-MockCalled GetMachineGroupNameFromAgentSetting -Times 1 -ParameterFilter { $tfsUrl.EndsWith("/tfs/testColl") }                                 
        }
        
        It "should return false if given agent settings are not same as existing agent running with ( machine group name different )" {
            $ret = Test-AgentSettingsAreSame -workingFolder "c:\test" -tfsUrl "http://mylocaltfs:8080/tfs/testColl" -collection "testColl" -projectName "testProj" -machineGroupName "my-mggrp1-different" -patToken "test-PAT"
            $ret | Should be "$false"                 
        }
        
         It "should return false if given agent settings are not same as existing agent running with ( tfs url different )" {
            $ret = Test-AgentSettingsAreSame -workingFolder "c:\test" -tfsUrl "http://mylocaltfsdifferentone:8080/tfs" -collection "testColl" -projectName "testProj" -machineGroupName "my-mggrp1" -patToken "test-PAT"
            $ret | Should be "$false"                 
        }
    }

    Context "GetMachineGroupNameFromAgentSetting should work fine" {    
        
        Mock ContructRESTCallUrl { return "test-Url" }
        Mock InvokeRestURlToGetMachineGroupName { return "machine-GroupName"}
       
        $existingAgentSetting =  '{  "agentId": 17,  "agentName": "Agent-Name-For-Mg",  "poolId": 2,  "serverUrl": "http://mylocaltfs:8080/tfs/",  "workFolder": "_work",  "projectName": "testProj",  "machineGroupId": 7 }' | ConvertFrom-Json
        
        It "should return correct machine group name in case machine group Id is saved with agent setting file" {
            $ret = GetMachineGroupNameFromAgentSetting -agentSetting $existingAgentSetting -tfsUrl "http://mylocaltfs:8080/tfs" -projectName "testProj" -patToken "test-PAT"
            $ret | Should be "machine-GroupName"     
            
            Assert-MockCalled ContructRESTCallUrl -Times 1
            Assert-MockCalled InvokeRestURlToGetMachineGroupName -Times 1
        }
        
        $existingAgentSetting =  '{  "agentId": 17,  "agentName": "Agent-Name-For-Mg",  "poolId": 2,  "serverUrl": "http://mylocaltfs:8080/tfs/",  "workFolder": "_work",  "projectName": "testProj",  "deploymentGroupID": 7 }' | ConvertFrom-Json
        
        It "should return correct machine group name in case deployment group Id is saved with agent setting file" {
            $ret = GetMachineGroupNameFromAgentSetting -agentSetting $existingAgentSetting -tfsUrl "http://mylocaltfs:8080/tfs" -projectName "testProj" -patToken "test-PAT"
            $ret | Should be "machine-GroupName"     
            
            Assert-MockCalled ContructRESTCallUrl -Times 1
            Assert-MockCalled InvokeRestURlToGetMachineGroupName -Times 1
        }
    }
    
    Context "ContructRESTCallUrl should work fine" {    
    
         It "should return correct REST " {         
            $tfsUrl = "https://myaccount.visualstudio.com"
            $projectName = "testProj"
            $machineGroupId = 7
            $expectedRESTUrl = $tfsUrl + ("/{0}/_apis/distributedtask/machinegroups/{1}" -f $projectName, $machineGroupId)
         
            $ret = ContructRESTCallUrl -tfsUrl $tfsUrl -projectName $projectName -machineGroupId $machineGroupId
            
            $ret | Should be $expectedRESTUrl         
         }    
    }
}
