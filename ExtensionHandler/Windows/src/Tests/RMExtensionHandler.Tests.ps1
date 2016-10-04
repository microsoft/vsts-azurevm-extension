$currentScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path

Import-Module "$currentScriptPath\..\bin\AzureExtensionHandler.psm1"
Import-Module "$currentScriptPath\..\bin\RMExtensionStatus.psm1"
Import-Module "$currentScriptPath\..\bin\RMExtensionHandler.psm1"

Describe "Start RM extension tests" {

    Context "Should clear up things properly" {
        
        Mock -ModuleName RMExtensionHandler Get-HandlerExecutionSequenceNumber {}
        Mock -ModuleName RMExtensionHandler Clear-StatusFile {}
        Mock -ModuleName RMExtensionHandler Clear-HandlerCache {}
        Mock -ModuleName RMExtensionHandler Clear-HandlerSubStatusMessage {}
        Mock -ModuleName RMExtensionHandler Initialize-ExtensionLogFile {}
        Mock -ModuleName RMExtensionHandler Add-HandlerSubStatus {}
        Mock -ModuleName RMExtensionHandler Set-HandlerStatus {}
        Mock -ModuleName RMExtensionHandler Write-Log {}
        
        Start-RMExtensionHandler

        It "should call clean up functions" {
            Assert-MockCalled -ModuleName RMExtensionHandler Get-HandlerExecutionSequenceNumber -Times 1
            Assert-MockCalled -ModuleName RMExtensionHandler Clear-StatusFile -Times 1
            Assert-MockCalled -ModuleName RMExtensionHandler Clear-HandlerCache -Times 1
            Assert-MockCalled -ModuleName RMExtensionHandler Clear-HandlerSubStatusMessage -Times 1
            Assert-MockCalled -ModuleName RMExtensionHandler Initialize-ExtensionLogFile -Times 1
        }

        It "should set handler status as Initilized" {
            Assert-MockCalled -ModuleName RMExtensionHandler Set-HandlerStatus -Times 1 -ParameterFilter { $Code -eq $RM_Extension_Status.Installing.Code}
            Assert-MockCalled -ModuleName RMExtensionHandler Add-HandlerSubStatus -Times 1 -ParameterFilter { $Code -eq $RM_Extension_Status.Initialized.Code}
        }
    }

    Context "Should skip enable if current seq number is same as last seq number" {
        
        Mock -ModuleName RMExtensionHandler Get-HandlerExecutionSequenceNumber { return 2 }
        Mock -ModuleName RMExtensionHandler Get-LastSequenceNumber { return 2 }
        Mock -ModuleName RMExtensionHandler Test-ExtensionDisabledMarkup { return $false }
        Mock -ModuleName RMExtensionHandler Clear-StatusFile {}
        Mock -ModuleName RMExtensionHandler Clear-HandlerCache {}
        Mock -ModuleName RMExtensionHandler Clear-HandlerSubStatusMessage {}
        Mock -ModuleName RMExtensionHandler Initialize-ExtensionLogFile {}
        Mock -ModuleName RMExtensionHandler Add-HandlerSubStatus {}
        Mock -ModuleName RMExtensionHandler Set-HandlerStatus {}
        Mock -ModuleName RMExtensionHandler Write-Log {}
        Mock -ModuleName RMExtensionHandler Exit-WithCode0 {} 
        
        Start-RMExtensionHandler

        It "should call clean up functions" {
            Assert-MockCalled -ModuleName RMExtensionHandler Exit-WithCode0 -Times 1
        }

        It "should set handler status as Initilized" {
            Assert-MockCalled -ModuleName RMExtensionHandler Add-HandlerSubStatus -Times 1 -ParameterFilter { $Code -eq $RM_Extension_Status.SkippedInstallation.Code}
        }
    }

    Context "Should not skip enable if current seq number is same as last seq number and extension was disabled" {
        
        Mock -ModuleName RMExtensionHandler Get-HandlerExecutionSequenceNumber { return 2 }
        Mock -ModuleName RMExtensionHandler Get-LastSequenceNumber { return 2 }
        Mock -ModuleName RMExtensionHandler Test-ExtensionDisabledMarkup { return $true }
        Mock -ModuleName RMExtensionHandler Clear-StatusFile {}
        Mock -ModuleName RMExtensionHandler Clear-HandlerCache {}
        Mock -ModuleName RMExtensionHandler Clear-HandlerSubStatusMessage {}
        Mock -ModuleName RMExtensionHandler Initialize-ExtensionLogFile {}
        Mock -ModuleName RMExtensionHandler Add-HandlerSubStatus {}
        Mock -ModuleName RMExtensionHandler Set-HandlerStatus {}
        Mock -ModuleName RMExtensionHandler Write-Log {}
        Mock -ModuleName RMExtensionHandler Exit-WithCode0 {} 
        
        Start-RMExtensionHandler

        It "should call clean up functions" {
            Assert-MockCalled -ModuleName RMExtensionHandler Exit-WithCode0 -Times 0
        }

        It "should set handler status as Initilized" {
            Assert-MockCalled -ModuleName RMExtensionHandler Add-HandlerSubStatus -Times 0 -ParameterFilter { $Code -eq $RM_Extension_Status.SkippedInstallation.Code}
            Assert-MockCalled -ModuleName RMExtensionHandler Add-HandlerSubStatus -Times 1 -ParameterFilter { $Code -eq $RM_Extension_Status.Initialized.Code}
        }
    }
}

Describe "Download agent tests" {

    Context "Should set error status if exception happens" {

        Mock -ModuleName RMExtensionHandler Write-Log{}
        Mock -ModuleName RMExtensionHandler Set-HandlerErrorStatus {}
        Mock -ModuleName RMExtensionHandler Add-HandlerSubStatus {}
        Mock -ModuleName RMExtensionHandler Invoke-GetAgentScript { throw New-Object System.Exception("some error")}
        Mock -ModuleName RMExtensionHandler Exit-WithCode0 {}

        Get-Agent @{}

        It "should call clean up functions" {
            Assert-MockCalled -ModuleName RMExtensionHandler Set-HandlerErrorStatus -Times 1 -ParameterFilter { $ErrorRecord.Exception.Message -eq "some error"}
        }
    }

    Context "Should set success status if no exception happens" {

        Mock -ModuleName RMExtensionHandler Write-Log{}
        Mock -ModuleName RMExtensionHandler Set-HandlerErrorStatus {}
        Mock -ModuleName RMExtensionHandler Add-HandlerSubStatus {}
        Mock -ModuleName RMExtensionHandler Invoke-GetAgentScript {}
        Mock -ModuleName RMExtensionHandler Set-HandlerStatus
        
        Get-Agent @{}

        It "should call clean up functions" {
            Assert-MockCalled -ModuleName RMExtensionHandler Add-HandlerSubStatus -Times 1 -ParameterFilter { $Code -eq $RM_Extension_Status.DownloadedDeploymentAgent.Code}
        }
    }
}

Describe "Pre-check agent tests" {

    Context "Should set error status if exception happens" {

        Mock -ModuleName RMExtensionHandler Write-Log{}
        Mock -ModuleName RMExtensionHandler Set-HandlerErrorStatus {}
        Mock -ModuleName RMExtensionHandler Add-HandlerSubStatus {}
        Mock -ModuleName RMExtensionHandler Test-AgentAlreadyExistsInternal { throw New-Object System.Exception("some error")}
        Mock -ModuleName RMExtensionHandler Exit-WithCode0 {}

        Test-AgentAlreadyExists @{}

        It "should call clean up functions" {
            Assert-MockCalled -ModuleName RMExtensionHandler Set-HandlerErrorStatus -Times 1 -ParameterFilter { $ErrorRecord.Exception.Message -eq "some error"}
        }
    }

    Context "Should set success status if no exception happens" {

        Mock -ModuleName RMExtensionHandler Write-Log{}
        Mock -ModuleName RMExtensionHandler Set-HandlerErrorStatus {}
        Mock -ModuleName RMExtensionHandler Add-HandlerSubStatus {}
        Mock -ModuleName RMExtensionHandler Test-AgentAlreadyExistsInternal {}
        Mock -ModuleName RMExtensionHandler Set-HandlerStatus
        
        Test-AgentAlreadyExists @{}

        It "should call clean up functions" {
            Assert-MockCalled -ModuleName RMExtensionHandler Add-HandlerSubStatus -Times 1 -ParameterFilter { $Code -eq $RM_Extension_Status.PreCheckedDeploymentAgent.Code}
        }
    }
}

Describe "configure agent tests" {

    Context "Should set error status if exception happens" {

        Mock -ModuleName RMExtensionHandler Write-Log{}
        Mock -ModuleName RMExtensionHandler Set-HandlerErrorStatus {}
        Mock -ModuleName RMExtensionHandler Add-HandlerSubStatus {}
        Mock -ModuleName RMExtensionHandler Invoke-ConfigureAgentScript { throw New-Object System.Exception("some error")}
        Mock -ModuleName RMExtensionHandler Exit-WithCode0 {}

        Register-Agent @{}

        It "should call clean up functions" {
            Assert-MockCalled -ModuleName RMExtensionHandler Set-HandlerErrorStatus -Times 1 -ParameterFilter { $ErrorRecord.Exception.Message -eq "some error"}
        }
    }

    Context "Should set success status if no exception happens" {

        Mock -ModuleName RMExtensionHandler Write-Log{}
        Mock -ModuleName RMExtensionHandler Set-HandlerErrorStatus {}
        Mock -ModuleName RMExtensionHandler Add-HandlerSubStatus {}
        Mock -ModuleName RMExtensionHandler Invoke-ConfigureAgentScript {}
        Mock -ModuleName RMExtensionHandler Set-HandlerStatus
        
        Register-Agent @{}

        It "should call clean up functions" {
            Assert-MockCalled -ModuleName RMExtensionHandler Add-HandlerSubStatus -Times 1 -ParameterFilter { $Code -eq $RM_Extension_Status.ConfiguredDeploymentAgent.Code}
        }
    }
}

Describe "remove agent tests" {
    Context "Should set proper status when agent is removed" {

        Mock -ModuleName RMExtensionHandler Write-Log{}
        Mock -ModuleName RMExtensionHandler Set-HandlerErrorStatus {}
        Mock -ModuleName RMExtensionHandler Add-HandlerSubStatus {}
        Mock -ModuleName RMExtensionHandler Set-HandlerStatus {}
        Mock -ModuleName RMExtensionHandler Invoke-RemoveAgentScript {}
        Remove-Agent @{}

        It "should set proper status" {
            Assert-MockCalled -ModuleName RMExtensionHandler Add-HandlerSubStatus -Times 1 -ParameterFilter { $Code -eq $RM_Extension_Status.RemovedAgent.Code}
            Assert-MockCalled -ModuleName RMExtensionHandler Set-HandlerStatus -Times 1 -ParameterFilter { $Code -eq $RM_Extension_Status.Uninstalling.Code}
        }
    }
}

Describe "parse vsts account name settings tests" {
    Context "Should add necessary fragments to VSTS url if it just accout name" {

        Mock -ModuleName RMExtensionHandler Write-Log{}
        Mock -ModuleName RMExtensionHandler Set-HandlerErrorStatus {}
        Mock -ModuleName RMExtensionHandler Add-HandlerSubStatus {}
        Mock -ModuleName RMExtensionHandler Set-HandlerStatus {}
        Mock -ModuleName RMExtensionHandler Get-HandlerSettings { 
            $inputSettings = @{
                publicSettings =  @{ 
                        VSTSAccountName = "abc"
                        TeamProject = "project"
                        MachineGroup = "group"
                        Tags = @()
                        AgentName = "name" 
                    };
                protectedSettings = @{
                        PATToken = "hash"
                }
            }
            return $inputSettings }
        Mock -ModuleName RMExtensionHandler Get-OSVersion { return @{ IsX64 = $true }}
        Mock -ModuleName RMExtensionHandler VeriftInputNotNull {}
        Mock -ModuleName RMExtensionHandler Format-TagsInput {}
        Mock -ModuleName RMExtensionHandler Test-Path { return $true }

        $settings = Get-ConfigurationFromSettings

        It "should set proper status" {
            $settings.VSTSUrl | Should Be "https://abc.visualstudio.com"
        }
    }
}

Describe "parse tags settings tests" {
    Context "Should copy array if input is array" {

        Mock -ModuleName RMExtensionHandler Write-Log{}
        Mock -ModuleName RMExtensionHandler Set-HandlerErrorStatus {}
        Mock -ModuleName RMExtensionHandler Add-HandlerSubStatus {}
        Mock -ModuleName RMExtensionHandler Set-HandlerStatus {}
        Mock -ModuleName RMExtensionHandler Get-HandlerSettings { 
            $inputSettings = @{
                publicSettings =  @{ 
                        VSTSAccountName = "abc"
                        TeamProject = "project"
                        MachineGroup = "group"
                        Tags = @("arrayValue1", "arrayValue2")
                        AgentName = "name" 
                    };
                protectedSettings = @{
                        PATToken = "hash"
                }
            }
            return $inputSettings }
        Mock -ModuleName RMExtensionHandler Get-OSVersion { return @{ IsX64 = $true }}
        Mock -ModuleName RMExtensionHandler VeriftInputNotNull {}
        Mock -ModuleName RMExtensionHandler Test-Path { return $true }

        $settings = Get-ConfigurationFromSettings

        It "tags should be an array with proper entries" {
            $settings.Tags.GetType().IsArray | Should Be True
            $settings.Tags[0] | Should Be "arrayValue1"
            $settings.Tags[1] | Should Be "arrayValue2"
        }
    }

    Context "Should sort and select unique tags" {

        Mock -ModuleName RMExtensionHandler Write-Log{}
        Mock -ModuleName RMExtensionHandler Set-HandlerErrorStatus {}
        Mock -ModuleName RMExtensionHandler Add-HandlerSubStatus {}
        Mock -ModuleName RMExtensionHandler Set-HandlerStatus {}
        Mock -ModuleName RMExtensionHandler Get-HandlerSettings { 
            $inputSettings = @{
                publicSettings =  @{ 
                        VSTSAccountName = "abc"
                        TeamProject = "project"
                        MachineGroup = "group"
                        Tags = @("bb", "dd", "bb", "aa")
                        AgentName = "name" 
                    };
                protectedSettings = @{
                        PATToken = "hash"
                }
            }
            return $inputSettings }
        Mock -ModuleName RMExtensionHandler Get-OSVersion { return @{ IsX64 = $true }}
        Mock -ModuleName RMExtensionHandler VeriftInputNotNull {}
        Mock -ModuleName RMExtensionHandler Test-Path { return $true }

        $settings = Get-ConfigurationFromSettings

        It "tags should be an array with unique sorted entries" {
            $settings.Tags[0] | Should Be "aa"
            $settings.Tags[1] | Should Be "bb"
            $settings.Tags[2] | Should Be "dd"
        }
    }

    Context "Should create array of values if input is hashtable" {
        
        Mock -ModuleName RMExtensionHandler Write-Log{}
        Mock -ModuleName RMExtensionHandler Set-HandlerErrorStatus {}
        Mock -ModuleName RMExtensionHandler Add-HandlerSubStatus {}
        Mock -ModuleName RMExtensionHandler Set-HandlerStatus {}
        Mock -ModuleName RMExtensionHandler Get-HandlerSettings { 
            $inputSettings = @{
                publicSettings =  @{ 
                        VSTSAccountName = "abc"
                        TeamProject = "project"
                        MachineGroup = "group"
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
        Mock -ModuleName RMExtensionHandler Get-OSVersion { return @{ IsX64 = $true }}
        Mock -ModuleName RMExtensionHandler VeriftInputNotNull {}
        Mock -ModuleName RMExtensionHandler Test-Path { return $true }

        $settings = Get-ConfigurationFromSettings

        It "tags should be an array with proper entries" {
            $settings.Tags.GetType().IsArray | Should Be True
            $settings.Tags[0] | Should Be "hashValue1"
            $settings.Tags[1] | Should Be "hashValue2"
        }
    }
}

Describe "AgentReconfigurationRequired tests" {

    Context "Should set error status if exception happens" {

        Mock -ModuleName RMExtensionHandler Write-Log{}
        Mock -ModuleName RMExtensionHandler Set-HandlerErrorStatus {}
        Mock -ModuleName RMExtensionHandler Add-HandlerSubStatus {}
        Mock -ModuleName RMExtensionHandler Test-AgentReConfigurationRequiredInternal { throw New-Object System.Exception("some error")}
        Mock -ModuleName RMExtensionHandler Exit-WithCode0 {}

        Test-AgentReconfigurationRequired @{}

        It "should call clean up functions" {
            Assert-MockCalled -ModuleName RMExtensionHandler Set-HandlerErrorStatus -Times 1 -ParameterFilter { $ErrorRecord.Exception.Message -eq "some error"}
        }
    }

    Context "Should set success status if no exception happens" {

        Mock -ModuleName RMExtensionHandler Write-Log{}
        Mock -ModuleName RMExtensionHandler Set-HandlerErrorStatus {}
        Mock -ModuleName RMExtensionHandler Add-HandlerSubStatus {}
        Mock -ModuleName RMExtensionHandler Test-AgentReConfigurationRequiredInternal { return $true}
        Mock -ModuleName RMExtensionHandler Set-HandlerStatus
        
        Test-AgentReconfigurationRequired @{}

        It "should call clean up functions" {
            Assert-MockCalled -ModuleName RMExtensionHandler Add-HandlerSubStatus -Times 1 -ParameterFilter { $Code -eq $RM_Extension_Status.CheckingAgentReConfigurationRequired.Code}
        }
    }
}