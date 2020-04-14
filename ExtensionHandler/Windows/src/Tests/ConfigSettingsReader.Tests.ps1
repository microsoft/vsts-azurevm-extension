$currentScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$currentScriptPath\..\bin\ConfigSettingsReader.ps1"

Describe "parse vsts account name settings tests" {
    Context "Should add necessary fragments to VSTS url if it just accout name" {

        Mock Write-Log{}
        Mock Add-HandlerSubStatus {}
        Mock Set-HandlerStatus {}
        Mock Get-HandlerSettings { 
            $inputSettings = @{
                publicSettings =  @{ 
                        VSTSAccountName = "tycjfchsdabvdsb"
                        TeamProject = "project"
                        DeploymentGroup = "group"
                        Tags = @()
                        AgentName = "name" 
                    };
                protectedSettings = @{
                        PATToken = "hash"
                }
            }
            return $inputSettings }
        Mock Verify-InputNotNull {}
        Mock Format-TagsInput {}

        $settings = Get-ConfigurationFromSettings

        It "should set proper status" {
            $settings.VSTSUrl | Should Be "https://tycjfchsdabvdsb.visualstudio.com" 
        }
    }

    Context "Should handle old hosted url" {

        Mock Write-Log{}
        Mock Add-HandlerSubStatus {}
        Mock Set-HandlerStatus {}
        Mock Get-HandlerSettings { 
            $inputSettings = @{
                publicSettings =  @{ 
                        VSTSAccountName = "https://tycjfchsdabvdsb.visualstudio.com"
                        TeamProject = "project"
                        DeploymentGroup = "group"
                        Tags = @()
                        AgentName = "name" 
                    };
                protectedSettings = @{
                        PATToken = "hash"
                }
            }
            return $inputSettings }
        Mock Verify-InputNotNull {}
        Mock Format-TagsInput {}
        Mock Invoke-RestMethod {
            $response = @{deploymentType = "hosted"}
            return $response
        }

        $settings = Get-ConfigurationFromSettings

        It "should set proper status" {
            $settings.VSTSUrl | Should Be "https://tycjfchsdabvdsb.visualstudio.com"
            $settings.PATToken | Should Be "hash"     
        }
    }

    Context "Should handle new hosted url" {

        Mock Write-Log{}
        Mock Add-HandlerSubStatus {}
        Mock Set-HandlerStatus {}
        Mock Get-HandlerSettings { 
            $inputSettings = @{
                publicSettings =  @{ 
                        VSTSAccountName = "https://codex.azure.com/tycjfchsdabvdsb"
                        TeamProject = "project"
                        DeploymentGroup = "group"
                        Tags = @()
                        AgentName = "name" 
                    };
                protectedSettings = @{
                        PATToken = "hash"
                }
            }
            return $inputSettings }
        Mock Verify-InputNotNull {}
        Mock Format-TagsInput {}
        Mock Invoke-RestMethod {
            $response = @{deploymentType = "hosted"}
            return $response
        }

        $settings = Get-ConfigurationFromSettings

        It "should set proper status" {
            $settings.VSTSUrl | Should Be "https://codex.azure.com/tycjfchsdabvdsb"
            $settings.PATToken | Should Be "hash"     
        }
    }

    Context "Should handle hosted url with collection" {

        Mock Write-Log{}
        Mock Add-HandlerSubStatus {}
        Mock Set-HandlerStatus {}
        Mock Get-HandlerSettings { 
            $inputSettings = @{
                publicSettings =  @{ 
                        VSTSAccountName = "https://tycjfchsdabvdsb.visualstudio.com/DefaultCollection/"
                        TeamProject = "project"
                        DeploymentGroup = "group"
                        Tags = @()
                        AgentName = "name" 
                    };
                protectedSettings = @{
                        PATToken = "hash"
                }
            }
            return $inputSettings }
        Mock Verify-InputNotNull {}
        Mock Format-TagsInput {}
        Mock Invoke-RestMethod {
            $response = @{deploymentType = "hosted"}
            return $response
        }

        $settings = Get-ConfigurationFromSettings

        It "should set proper status" {
            $settings.VSTSUrl | Should Be "https://tycjfchsdabvdsb.visualstudio.com/defaultcollection/"       
        }
    }

    Context "Should handle on-prem url" {

        Mock Write-Log{}
        Mock Add-HandlerSubStatus {}
        Mock Set-HandlerStatus {}
        Mock Get-HandlerSettings { 
            $inputSettings = @{
                publicSettings =  @{ 
                        VSTSAccountName = "http://localhost:8080/tfs/defaultcollection"
                        TeamProject = "project"
                        DeploymentGroup = "group"
                        Tags = @()
                        AgentName = "name" 
                    };
                protectedSettings = @{
                        PATToken = "hash"
                }
            }
            return $inputSettings }
        Mock Verify-InputNotNull {}
        Mock Format-TagsInput {}
        Mock Invoke-RestMethod {
            $response = @{deploymentType = "onPremises"}
            return $response
        }

        $settings = Get-ConfigurationFromSettings

        It "should set proper status" {
            $settings.VSTSUrl | Should Be "http://localhost:8080/tfs/defaultcollection"            
        }
    }

    Context "Should handle on-prem url with additional components" {

        Mock Write-Log{}
        Mock Add-HandlerSubStatus {}
        Mock Set-HandlerStatus {}
        Mock Get-HandlerSettings { 
            $inputSettings = @{
                publicSettings =  @{ 
                        VSTSAccountName = "http://localhost:8080///tfs/defaultcollection/a/b//c/d//"
                        TeamProject = "project"
                        DeploymentGroup = "group"
                        Tags = @()
                        AgentName = "name" 
                    };
                protectedSettings = @{
                        PATToken = "hash"
                }
            }
            return $inputSettings }
        Mock Verify-InputNotNull {}
        Mock Format-TagsInput {}
        Mock Invoke-RestMethod {
            $response = @{deploymentType = "onPremises"}
            return $response
        }

        $settings = Get-ConfigurationFromSettings

        It "should set proper status" {
            $settings.VSTSUrl | Should Be "http://localhost:8080///tfs/defaultcollection/a/b//c/d//"       
        }
    }

    Context "Should throw error if url is not well formed" {

        Mock Write-Log{}
        Mock Set-ErrorStatusAndErrorExit {}
        Mock Add-HandlerSubStatus {}
        Mock Set-HandlerStatus {}
        Mock Get-HandlerSettings { 
            $inputSettings = @{
                publicSettings =  @{ 
                        VSTSAccountName = "http://localhost:8080/"
                        TeamProject = "project"
                        DeploymentGroup = "group"
                        Tags = @()
                        AgentName = "name" 
                    };
                protectedSettings = @{
                        PATToken = "hash"
                }
            }
            return $inputSettings }
        Mock Verify-InputNotNull {}
        Mock Format-TagsInput {}
        Mock Invoke-WebRequest {
            $response = @{
                StatusCode = 200
                Content = (@{deploymentType = "onPremises"} | ConvertTo-Json)
            }
            return $response
        }

        It "should set proper status" {
            Get-ConfigurationFromSettings
            Assert-MockCalled Set-ErrorStatusAndErrorExit -Times 1 #-ParameterFilter { $ErrorRecord.Exception.Message -eq "Invalid value for the input 'VSTS account url'. It should be in the format http(s)://<server>/<application>/<collection> for on-premise deployment."}
        }
    }
}

Describe "parse tags settings tests" {
    Context "Should copy array if input is array" {

        Mock Write-Log{}
        Mock Add-HandlerSubStatus {}
        Mock Set-HandlerStatus {}
        Mock Get-HandlerSettings { 
            $inputSettings = @{
                publicSettings =  @{ 
                        VSTSAccountName = "tycjfchsdabvdsb"
                        TeamProject = "project"
                        DeploymentGroup = "group"
                        Tags = @("arrayValue1", "arrayValue2")
                        AgentName = "name" 
                    };
                protectedSettings = @{
                        PATToken = "hash"
                }
            }
            return $inputSettings }
        Mock Verify-InputNotNull {}

        $settings = Get-ConfigurationFromSettings

        It "tags should be an array with proper entries" {
            $settings.Tags.GetType().IsArray | Should Be True
            $settings.Tags[0] | Should Be "arrayValue1"
            $settings.Tags[1] | Should Be "arrayValue2"
        }
    }

    Context "Should sort and select unique tags" {

        Mock Write-Log{}
        Mock Add-HandlerSubStatus {}
        Mock Set-HandlerStatus {}
        Mock Get-HandlerSettings { 
            $inputSettings = @{
                publicSettings =  @{ 
                        VSTSAccountName = "tycjfchsdabvdsb"
                        TeamProject = "project"
                        DeploymentGroup = "group"
                        Tags = @("bb", "dd", "bb", "aa")
                        AgentName = "name" 
                    };
                protectedSettings = @{
                        PATToken = "hash"
                }
            }
            return $inputSettings }
        Mock Verify-InputNotNull {}

        $settings = Get-ConfigurationFromSettings

        It "tags should be an array with unique sorted entries" {
            $settings.Tags[0] | Should Be "aa"
            $settings.Tags[1] | Should Be "bb"
            $settings.Tags[2] | Should Be "dd"
        }
    }

    Context "Should create array of values if input is hashtable" {
        
        Mock Write-Log{}
        Mock Add-HandlerSubStatus {}
        Mock Set-HandlerStatus {}
        Mock Get-HandlerSettings { 
            $inputSettings = @{
                publicSettings =  @{ 
                        VSTSAccountName = "tycjfchsdabvdsb"
                        TeamProject = "project"
                        DeploymentGroup = "group"
                        Tags = @{ 
                            tag1 = "hashValue1"
                            tag2 = "hashValue2" 
                        }
                        AgentName = "name" 
                    };
                protectedSettings = @{
                        PATToken = "hash"
                }
            }
            return $inputSettings }
        Mock Verify-InputNotNull {}

        $settings = Get-ConfigurationFromSettings

        It "tags should be an array with proper entries" {
            $settings.Tags.GetType().IsArray | Should Be True
            $settings.Tags[0] | Should Be "hashValue1"
            $settings.Tags[1] | Should Be "hashValue2"
        }
    }

    Context "Should create array of values if input is string" {
        
        Mock Write-Log{}
        Mock Add-HandlerSubStatus {}
        Mock Set-HandlerStatus {}
        Mock Get-HandlerSettings { 
            $inputSettings = @{
                publicSettings =  @{ 
                        VSTSAccountName = "tycjfchsdabvdsb"
                        TeamProject = "project"
                        DeploymentGroup = "group"
                        Tags = "tag1,  ,  tag2 ,, tag3,"
                        AgentName = "name" 
                    };
                protectedSettings = @{
                        PATToken = "hash"
                }
            }
            return $inputSettings }
        Mock Verify-InputNotNull {}

        $settings = Get-ConfigurationFromSettings

        It "tags should be an array with proper entries" {
            $settings.Tags.GetType().IsArray | Should Be True
            $settings.Tags[0] | Should Be "tag1"
            $settings.Tags[1] | Should Be "tag2"
            $settings.Tags[2] | Should Be "tag3"            
        }
    }

    Context "Windows user credentials are not present in settings" {
        
        Mock Write-Log{}
        Mock Add-HandlerSubStatus {}
        Mock Set-HandlerStatus {}
        Mock Get-HandlerSettings { 
            $inputSettings = @{
                publicSettings =  @{ 
                        VSTSAccountName = "tycjfchsdabvdsb"
                        TeamProject = "project"
                        DeploymentGroup = "group"
                        Tags = "tag1,  ,  tag2 ,, tag3,"
                        AgentName = "name" 
                    };
                protectedSettings = @{
                        PATToken = "hash"
                }
            }
            return $inputSettings }
        Mock Verify-InputNotNull {}

        $settings = Get-ConfigurationFromSettings

        It "should set windows user credentials as empty strings" {
            $settings.WindowsLogonAccountName | Should Be ""
            $settings.WindowsLogonPassword | Should Be ""
        }
    }

    Context "Windows user credentials are present in settings" {
        
        Mock Write-Log{}
        Mock Add-HandlerSubStatus {}
        Mock Set-HandlerStatus {}
        Mock Get-HandlerSettings { 
            $inputSettings = @{
                publicSettings =  @{ 
                        VSTSAccountName = "tycjfchsdabvdsb"
                        TeamProject = "project"
                        DeploymentGroup = "group"
                        Tags = "tag1,  ,  tag2 ,, tag3,"
                        AgentName = "name" 
                        UserName = "domain\testuser"
                    };
                protectedSettings = @{
                        PATToken = "hash"
                        Password = "password"
                }
            }
            return $inputSettings }
        Mock Verify-InputNotNull {}

        $settings = Get-ConfigurationFromSettings

        It "config should contain the windows user credentials" {
            $settings.WindowsLogonAccountName | Should Be "domain\testuser"
            $settings.WindowsLogonPassword | Should Be "password"         
        }
    }
}

Describe "Pipelines mode should have independent settings from regular deployment" {
    Context "When Pipelines mode is enabled, pool name is validated and deployment group is not" {
        Mock Write-Log{}
        Mock Add-HandlerSubStatus {}
        Mock Set-HandlerStatus {}
        Mock Get-HandlerSettings { 
            $inputSettings = @{
                publicSettings =  @{ 
                        IsPipelinesAgent = $true
                        PoolName = "pool"
                        VSTSAccountName = "tycjfchsdabvdsb"
                        AgentName = "name" 
                    };
                protectedSettings = @{
                        PATToken = "hash"
                        Password = "password"
                }
            }
            return $inputSettings 
        }

        It "should not throw when DeploymentGroup and TeamProject are not provided when IsPipelinesAgent is true" {
            { Get-ConfigurationFromSettings } | Should Not Throw
        }
    }

    Context "When Pipelines mode is not enabled, pool name is not validated" {
        Mock Write-Log{}
        Mock Add-HandlerSubStatus {}
        Mock Set-HandlerStatus {}
        Mock Get-HandlerSettings { 
            $inputSettings = @{
                publicSettings =  @{ 
                        IsPipelinesAgent = $false
                        VSTSAccountName = "tycjfchsdabvdsb"
                        TeamProject = "project"
                        DeploymentGroup = "group"
                        Tags = @()
                        AgentName = "name" 
                    };
                protectedSettings = @{
                        PATToken = "hash"
                }
            }
            return $inputSettings }

        It "should not throw when PoolName is not provided when IsPipelinesAgent is false" {
            { Get-ConfigurationFromsettings } | Should Not Throw
        }
    }
}