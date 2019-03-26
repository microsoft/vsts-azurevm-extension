$currentScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$currentScriptPath\..\bin\AgentSettingsHelper.ps1"

Describe "Agent ExistenceChecker Tests" {

    Context "Test-ConfiguredAgentExists Should true or false as per existence of .agent file" {
        
        Mock GetAgentSettingFilePath { return "t:\nonExistingPath\.agent"}

        It "should return false if .agent file does not exist" {
            $ret = Test-ConfiguredAgentExists "c:\123"     
            $ret | Should be "$false"                 
        }

        Mock GetAgentSettingFilePath { return "$currentScriptPath\..\bin\AgentSettingsHelper.ps1"}
        
        It "should return true if .agent file does not exist" {
            $ret = Test-ConfiguredAgentExists "c:\123"     
            $ret | Should be "$true"     
        }
    }   
    
    Context "Test-AgentSettingsAreSame should work fine" {
        
        $agentSettings =  '{  "agentId": 17,  "agentName": "Agent-Name-For-Dg",  "poolId": 2,  "serverUrl": "http://mylocaltfs:8080/tfs",  "collectionName": "testColl", "workFolder": "_work",  "projectName": "testProj",  "deploymentGroupId": 1 }' | ConvertFrom-Json        
        
        Mock GetAgentSettingFilePath { return "$currentScriptPath\..\bin\AgentSettingsHelper.ps1"}
        Mock Get-AgentSettings { return $agentSettings }
        Mock GetDeploymentGroupDataFromAgentSetting { return ('{ "machines":[{"tags":["t1","tag1","zxfzxcz"],"id":5022},{"tags":["t1"],"id":5023}],"machineCount":2,"id":2934,"project":{"id":"b924d689-3eae-4116-8443-9a17392d8544","name":"testProj"},"name":"my-dggrp1","pool":{"id":352,"scope":"0efb4611-d565-4cd1-9a64-7d6cb6d7d5f0","name":"01c05ec2-bde8-48e8-a3ad-7838e92d3455","isHosted":false,"poolType":"deployment"} }' | ConvertFrom-Json ) }
        
        It "should return true if given agent settings are same as existing agent running with" {
            $ret = Test-AgentSettingsAreSame -workingFolder "c:\test" -tfsUrl "http://mylocaltfs:8080/tfs/testColl" -projectName "testProj" -deploymentGroupName "my-dggrp1" -patToken "test-PAT"
            $ret | Should be "$true"

            Assert-MockCalled GetDeploymentGroupDataFromAgentSetting -Times 1 -ParameterFilter { $tfsUrl.EndsWith("/tfs/testColl") }             
        }

        It "should return false if given agent settings are not same as existing agent running with ( project name different )" {
            $ret = Test-AgentSettingsAreSame -workingFolder "c:\test" -tfsUrl "http://mylocaltfs:8080/tfs/testColl" -projectName "testProjDifferentOne" -deploymentGroupName "my-dggrp1" -patToken "test-PAT"
            $ret | Should be "$false"

            Assert-MockCalled GetDeploymentGroupDataFromAgentSetting -Times 1 -ParameterFilter { $tfsUrl.EndsWith("/tfs/testColl") }                                 
        }
        
        It "should return false if given agent settings are not same as existing agent running with ( deployment group name different )" {
            $ret = Test-AgentSettingsAreSame -workingFolder "c:\test" -tfsUrl "http://mylocaltfs:8080/tfs/testColl" -projectName "testProj" -deploymentGroupName "my-dggrp1-different" -patToken "test-PAT"
            $ret | Should be "$false"                 
        }
        
         It "should return false if given agent settings are not same as existing agent running with ( tfs url different )" {
            $ret = Test-AgentSettingsAreSame -workingFolder "c:\test" -tfsUrl "http://mylocaltfsdifferentone:8080/tfs/testColl" -projectName "testProj" -deploymentGroupName "my-dggrp1" -patToken "test-PAT"
            $ret | Should be "$false"                 
        }

        It "should return false if given agent settings are not same as existing agent running with ( tfs different collection)" {
            $ret = Test-AgentSettingsAreSame -workingFolder "c:\test" -tfsUrl "http://mylocaltfs:8080/tfs/testDifferentColl" -projectName "testProj" -deploymentGroupName "my-dggrp1" -patToken "test-PAT"
            $ret | Should be "$false"                 
        }
    }

    Context "GetDeploymentGroupDataFromAgentSetting should work fine" {    
        
        Mock InvokeRestURlToGetDeploymentGroupData { return ('{ "machines":[{"tags":["t1","tag1","zxfzxcz"],"id":5022},{"tags":["t1"],"id":5023}],"machineCount":2,"id":2934,"project":{"id":"b924d689-3eae-4116-8443-9a17392d8544","name":"testProj"},"name":"deployment-GroupName","pool":{"id":352,"scope":"0efb4611-d565-4cd1-9a64-7d6cb6d7d5f0","name":"01c05ec2-bde8-48e8-a3ad-7838e92d3455","isHosted":false,"poolType":"deployment"} }' | ConvertFrom-Json ) }
        
        $existingAgentSetting =  '{  "agentId": 17,  "agentName": "Agent-Name-For-Dg",  "poolId": 2,  "serverUrl": "http://mylocaltfs:8080/tfs/",  "workFolder": "_work",  "projectId": "testProj",  "deploymentGroupId": 7 }' | ConvertFrom-Json
        
        It "should return correct deployment group name in case deployment group Id is saved with agent setting file" {
            $ret = GetDeploymentGroupDataFromAgentSetting -agentSetting $existingAgentSetting -tfsUrl "http://mylocaltfs:8080/tfs" -patToken "test-PAT"
            $ret.name | Should be "deployment-GroupName"     
            
            Assert-MockCalled InvokeRestURlToGetDeploymentGroupData -Times 1 -ParameterFilter { $restCallUrl.Equals("http://mylocaltfs:8080/tfs/testProj/_apis/distributedtask/deploymentgroups/7?api-version=5.0-preview.1") }
        }
        
        $existingAgentSetting =  '{  "agentId": 17,  "agentName": "Agent-Name-For-Dg",  "poolId": 2,  "serverUrl": "http://mylocaltfs:8080/tfs/",  "workFolder": "_work",  "projectId": "b924d649-3eae-4236-8443-9a17392d8544",  "deploymentGroupID": 7 }' | ConvertFrom-Json
        It "should return correct project id for deployment group in case project Id is saved with agent setting file" {
            $ret = GetDeploymentGroupDataFromAgentSetting -agentSetting $existingAgentSetting -tfsUrl "http://mylocaltfs:8080/tfs" -patToken "test-PAT"
            $ret.project.Name | Should be "testProj"     
            
            Assert-MockCalled InvokeRestURlToGetDeploymentGroupData -Times 1
        }
    }
}
