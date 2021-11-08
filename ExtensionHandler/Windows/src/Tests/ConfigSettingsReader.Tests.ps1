BeforeAll {
    . "$PSScriptRoot\..\bin\ConfigSettingsReader.ps1"
}
Describe "parse vsts account name settings tests" {
    Context "Should add necessary fragments to VSTS url if it just accout name" {

        BeforeAll {
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
                return $inputSettings 
            }
            Mock Verify-InputNotNull {}
            Mock Format-TagsInput {}
        }

        It "should set proper status" {
            $settings = Get-ConfigurationFromSettings
            $settings.VSTSUrl | Should -Be "https://tycjfchsdabvdsb.visualstudio.com" 
        }
    }

    Context "Should handle old hosted url" {

        BeforeAll {
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
                return $inputSettings 
            }
            Mock Verify-InputNotNull {}
            Mock Format-TagsInput {}
            Mock Invoke-RestMethod {
                $response = @{deploymentType = "hosted"}
                return $response
            }
        }

        It "should set proper status" {
            $settings = Get-ConfigurationFromSettings
            $settings.VSTSUrl | Should -Be "https://tycjfchsdabvdsb.visualstudio.com"
            $settings.PATToken | Should -Be "hash"     
        }
    }

    Context "Should handle new hosted url" {

        BeforeAll {
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
                return $inputSettings 
            }
            Mock Verify-InputNotNull {}
            Mock Format-TagsInput {}
            Mock Invoke-RestMethod {
                $response = @{deploymentType = "hosted"}
                return $response
            }
        }

        It "should set proper status" {
            $settings = Get-ConfigurationFromSettings
            $settings.VSTSUrl | Should -Be "https://codex.azure.com/tycjfchsdabvdsb"
            $settings.PATToken | Should -Be "hash"     
        }
    }

    Context "Should handle hosted url with collection" {

        BeforeAll {
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
                return $inputSettings 
            }
            Mock Verify-InputNotNull {}
            Mock Format-TagsInput {}
            Mock Invoke-RestMethod {
                $response = @{deploymentType = "hosted"}
                return $response
            }
        }

        It "should set proper status" {
            $settings = Get-ConfigurationFromSettings
            $settings.VSTSUrl | Should -Be "https://tycjfchsdabvdsb.visualstudio.com/defaultcollection/"       
        }
    }

    Context "Should handle on-prem url" {

        BeforeAll {

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
                return $inputSettings 
            }
            Mock Verify-InputNotNull {}
            Mock Format-TagsInput {}
            Mock Invoke-RestMethod {
                $response = @{deploymentType = "onPremises"}
                return $response
            }
        }

        It "should set proper status" {
            $settings = Get-ConfigurationFromSettings
            $settings.VSTSUrl | Should -Be "http://localhost:8080/tfs/defaultcollection"            
        }
    }

    Context "Should handle on-prem url with additional components" {

        BeforeAll {
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
                return $inputSettings 
            }
            Mock Verify-InputNotNull {}
            Mock Format-TagsInput {}
            Mock Invoke-RestMethod {
                $response = @{deploymentType = "onPremises"}
                return $response
            }
        }

        It "should set proper status" {
            $settings = Get-ConfigurationFromSettings
            $settings.VSTSUrl | Should -Be "http://localhost:8080///tfs/defaultcollection/a/b//c/d//"       
        }
    }

    Context "Should throw error if url is not well formed" {

        BeforeAll {
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
                return $inputSettings 
            }
            Mock Verify-InputNotNull {}
            Mock Format-TagsInput {}
            Mock Invoke-WebRequest {
                $response = @{
                    StatusCode = 200
                    Content = (@{deploymentType = "onPremises"} | ConvertTo-Json)
                }
                return $response
            }
        }

        It "should set proper status" {
            Get-ConfigurationFromSettings
            Assert-MockCalled Set-ErrorStatusAndErrorExit -Times 1 #-ParameterFilter { $ErrorRecord.Exception.Message -eq "Invalid value for the input 'VSTS account url'. It should be in the format http(s)://<server>/<application>/<collection> for on-premise deployment."}
        }
    }
}

Describe "parse tags settings tests" {
    Context "Should copy array if input is array" {
        BeforeAll {

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
                return $inputSettings 
            }
            Mock Verify-InputNotNull {}
        }

        It "tags should be an array with proper entries" {
            $settings = Get-ConfigurationFromSettings
            $settings.Tags.GetType().IsArray | Should -Be True
            $settings.Tags[0] | Should -Be "arrayValue1"
            $settings.Tags[1] | Should -Be "arrayValue2"
        }
    }

    Context "Should sort and select unique tags" {

        BeforeAll {
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
                return $inputSettings 
            }
            Mock Verify-InputNotNull {}
        }

        It "tags should be an array with unique sorted entries" {
            $settings = Get-ConfigurationFromSettings
            $settings.Tags[0] | Should -Be "aa"
            $settings.Tags[1] | Should -Be "bb"
            $settings.Tags[2] | Should -Be "dd"
        }
    }

    Context "Should create array of values if input is hashtable" {
        
        BeforeAll {
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
                return $inputSettings 
            }
            Mock Verify-InputNotNull {}
        }

        It "tags should be an array with proper entries" {
            $settings = Get-ConfigurationFromSettings
            $settings.Tags.GetType().IsArray | Should -Be True
            $settings.Tags[0] | Should -Be "hashValue1"
            $settings.Tags[1] | Should -Be "hashValue2"
        }
    }

    Context "Should create array of values if input is string" {
        
        BeforeAll {
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
                return $inputSettings 
            }
            Mock Verify-InputNotNull {}
        }

        It "tags should be an array with proper entries" {
            $settings = Get-ConfigurationFromSettings
            $settings.Tags.GetType().IsArray | Should -Be True
            $settings.Tags[0] | Should -Be "tag1"
            $settings.Tags[1] | Should -Be "tag2"
            $settings.Tags[2] | Should -Be "tag3"            
        }
    }

    Context "Windows user credentials are not present in settings" {
        
        BeforeAll {
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
                return $inputSettings 
            }
            Mock Verify-InputNotNull {}
        }

        It "should set windows user credentials as empty strings" {
            $settings = Get-ConfigurationFromSettings
            $settings.WindowsLogonAccountName | Should -Be ""
            $settings.WindowsLogonPassword | Should -Be ""
        }
    }

    Context "Windows user credentials are present in settings" {
        
        BeforeAll {
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
                return $inputSettings 
            }
            Mock Verify-InputNotNull {}
        }

        It "config should contain the windows user credentials" {
            $settings = Get-ConfigurationFromSettings
            $settings.WindowsLogonAccountName | Should -Be "domain\testuser"
            $settings.WindowsLogonPassword | Should -Be "password"         
        }
    }
}