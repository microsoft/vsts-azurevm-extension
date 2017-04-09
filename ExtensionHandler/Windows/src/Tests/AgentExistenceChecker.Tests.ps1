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
        
        $agentSettings =  '{  "agentId": 17,  "agentName": "Agent-Name-For-Dg",  "poolId": 2,  "serverUrl": "http://mylocaltfs:8080/tfs/testColl",  "workFolder": "_work",  "projectName": "testProj",  "deploymentGroupId": 1 }' | ConvertFrom-Json        
        
        Mock GetAgentSettingFilePath { return "$currentScriptPath\..\bin\AgentExistenceChecker.ps1"}
        Mock Get-AgentSettings { return $agentSettings }
        Mock GetDeploymentGroupNameFromAgentSetting { return "my-dggrp1" }
        
        It "should return true if given agent settings are same as existing agent running with" {
            $ret = Test-AgentSettingsAreSame -workingFolder "c:\test" -tfsUrl "http://mylocaltfs:8080/tfs/testColl" -collection "" -projectName "testProj" -deploymentGroupName "my-dggrp1" -patToken "test-PAT"
            $ret | Should be "$true"

            Assert-MockCalled GetDeploymentGroupNameFromAgentSetting -Times 1 -ParameterFilter { $tfsUrl.EndsWith("/tfs/testColl") }             
        }

        It "should return false if given agent settings are not same as existing agent running with ( project name different )" {
            $ret = Test-AgentSettingsAreSame -workingFolder "c:\test" -tfsUrl "http://mylocaltfs:8080/tfs/testColl" -collection "testColl" -projectName "testProjDifferentOne" -deploymentGroupName "my-dggrp1" -patToken "test-PAT"
            $ret | Should be "$false"

            Assert-MockCalled GetDeploymentGroupNameFromAgentSetting -Times 1 -ParameterFilter { $tfsUrl.EndsWith("/tfs/testColl") }                                 
        }
        
        It "should return false if given agent settings are not same as existing agent running with ( deployment group name different )" {
            $ret = Test-AgentSettingsAreSame -workingFolder "c:\test" -tfsUrl "http://mylocaltfs:8080/tfs/testColl" -collection "testColl" -projectName "testProj" -deploymentGroupName "my-dggrp1-different" -patToken "test-PAT"
            $ret | Should be "$false"                 
        }
        
         It "should return false if given agent settings are not same as existing agent running with ( tfs url different )" {
            $ret = Test-AgentSettingsAreSame -workingFolder "c:\test" -tfsUrl "http://mylocaltfsdifferentone:8080/tfs" -collection "testColl" -projectName "testProj" -deploymentGroupName "my-dggrp1" -patToken "test-PAT"
            $ret | Should be "$false"                 
        }
    }

    Context "GetDeploymentGroupNameFromAgentSetting should work fine" {    
        
        Mock ContructRESTCallUrl { return "test-Url" }
        Mock InvokeRestURlToGetDeploymentGroupName { return "deployment-GroupName"}
       
        $existingAgentSetting =  '{  "agentId": 17,  "agentName": "Agent-Name-For-Dg",  "poolId": 2,  "serverUrl": "http://mylocaltfs:8080/tfs/",  "workFolder": "_work",  "projectName": "testProj",  "machineGroupId": 7 }' | ConvertFrom-Json
        
        It "should return correct deployment group name in case machine group Id is saved with agent setting file" {
            $ret = GetDeploymentGroupNameFromAgentSetting -agentSetting $existingAgentSetting -tfsUrl "http://mylocaltfs:8080/tfs" -projectName "testProj" -patToken "test-PAT"
            $ret | Should be "deployment-GroupName"     
            
            Assert-MockCalled ContructRESTCallUrl -Times 1
            Assert-MockCalled InvokeRestURlToGetDeploymentGroupName -Times 1
        }
        
        $existingAgentSetting =  '{  "agentId": 17,  "agentName": "Agent-Name-For-Dg",  "poolId": 2,  "serverUrl": "http://mylocaltfs:8080/tfs/",  "workFolder": "_work",  "projectName": "testProj",  "deploymentGroupID": 7 }' | ConvertFrom-Json
        
        It "should return correct deployment group name in case deployment group Id is saved with agent setting file" {
            $ret = GetDeploymentGroupNameFromAgentSetting -agentSetting $existingAgentSetting -tfsUrl "http://mylocaltfs:8080/tfs" -projectName "testProj" -patToken "test-PAT"
            $ret | Should be "deployment-GroupName"     
            
            Assert-MockCalled ContructRESTCallUrl -Times 1
            Assert-MockCalled InvokeRestURlToGetDeploymentGroupName -Times 1
        }
    }
    
    Context "ContructRESTCallUrl should work fine" {    
    
         It "should return correct REST " {         
            $tfsUrl = "https://myaccount.visualstudio.com"
            $projectName = "testProj"
            $deploymentGroupId = 7
            $expectedRESTUrl = $tfsUrl + ("/{0}/_apis/distributedtask/deploymentgroups/{1}" -f $projectName, $deploymentGroupId)
         
            $ret = ContructRESTCallUrl -tfsUrl $tfsUrl -projectName $projectName -deploymentGroupId $deploymentGroupId
            
            $ret | Should be $expectedRESTUrl         
         }    
    }
}
