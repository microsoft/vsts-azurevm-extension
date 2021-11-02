BeforeAll {
    Import-Module "$PSScriptRoot\..\bin\AzureExtensionHandler.psm1"
    . "$PSScriptRoot\..\bin\RMExtensionUtilities.ps1"
}
Describe "Handler environment tests" {

    Context "Should get settings from file correctly " {

        BeforeAll {
            Mock -ModuleName AzureExtensionHandler Read-HandlerEnvironmentFile { 
                $mockHandlerEnvironmentData = @(
                    @{  
                        handlerEnvironment = @{ 
                            logFolder = "E:\\work\\RM\\VMExtension\\RMExtension\\Logs"
                            configFolder = "E:\\work\\RM\\VMExtension\\RMExtension\\RuntimeSettings"
                        }
                        version = 1
                    }
                )
                return ,$mockHandlerEnvironmentData
            }

            $handlerEnvironment = Get-HandlerEnvironment -Refresh
        }

        It "should return correct log folder" {
            $handlerEnvironment.logFolder | Should -Be "E:\\work\\RM\\VMExtension\\RMExtension\\Logs"
        }

        It "should return correct config folder" {
            $handlerEnvironment.configFolder | Should -Be "E:\\work\\RM\\VMExtension\\RMExtension\\RuntimeSettings"
        }
    }
}

Describe "Handler sequence number tests" {
    Context "Should detect sequence number correctly" {

        BeforeAll {
            Mock -ModuleName AzureExtensionHandler Read-HandlerEnvironmentFile { 
                $mockHandlerEnvironmentData = @(
                    @{  
                        handlerEnvironment = @{ 
                            logFolder = "E:\\work\\RM\\VMExtension\\RMExtension\\Logs"
                            configFolder = "TestDrive:\\"
                        }
                        version = 1
                    }
                )

                return ,$mockHandlerEnvironmentData
            }

            $testPath1 = "TestDrive:\\1.settings"
            Set-Content $testPath1 -value "my test text." 
            $testPath2 = "TestDrive:\\2.settings"
            Set-Content $testPath2 -value "my test text."
        }

        It "should return correct sequence number" {
            $seqNo = Get-HandlerExecutionSequenceNumber -Refresh
            $seqNo | Should -Be "2"
        }
    }
}

Describe "Handler settings tests" {
    Context "Should read config settings from file" {

        BeforeAll {
            Mock -ModuleName AzureExtensionHandler Read-HandlerEnvironmentFile { 
                $mockHandlerEnvironmentData = @(
                    @{  
                        handlerEnvironment = @{ 
                            logFolder = "E:\\work\\RM\\VMExtension\\RMExtension\\Logs"
                            configFolder = "TestDrive:\"
                        }
                        version = 1
                    }
                )

                return ,$mockHandlerEnvironmentData
            }
            Mock -ModuleName AzureExtensionHandler Remove-ProtectedSettingsFromConfigFile {}

            $testPath1 = "TestDrive:\\1.settings"
            Set-Content $testPath1 -value "{ `
                                            `"runtimeSettings`": [{ `
                                                `"handlerSettings`": { `
                                                    `"publicSettings`": { `
                                                        `"VSTSAccountName`": `"mseng`", `
                                                        `"Pool`": `"biprasad`" `
                                                    } ,`
                                                    `"protectedSettings`": `"`"`
                                                } `
                                            }] `
                                        }" 

        }

        It "should return correct public settings" {
            $settings = Get-HandlerSettings -Refresh
            $settings.publicSettings.VSTSAccountName | Should -Be "mseng"
            $settings.publicSettings.Pool | Should -Be "biprasad"
            Assert-MockCalled -ModuleName AzureExtensionHandler Remove-ProtectedSettingsFromConfigFile -Times 0
        }
    }
}

Describe "Handler status tests" {
    Context "Handler status and sub-status should be written and read in proper format" {

        BeforeAll {
            Mock -ModuleName AzureExtensionHandler Read-HandlerEnvironmentFile { 
                $mockHandlerEnvironmentData = @(
                    @{  
                        handlerEnvironment = @{ 
                            logFolder = "TestDrive:\"
                            statusFolder = "TestDrive:\"
                        }
                        version = 1
                    }
                )

                return ,$mockHandlerEnvironmentData
            }

            $testPath1 = "TestDrive:\\1.settings"
            Set-Content $testPath1 -value "my test text." 

            $testPath1 = "TestDrive:\\1.status"
            Set-Content $testPath1 -value "" 

            Get-HandlerEnvironment -Refresh
            Initialize-ExtensionLogFile
    
            Set-HandlerStatus -Code 1432 -Message "some status msg 1" -Status transitioning
        }

        It "should have correct status and sub-status properties" {
            Add-HandlerSubStatus -Code 1433 -Message "sub-status message 1" -operationName "some operation 1"
            $status = Get-HandlerStatus -SequenceNumber 1
            $status.status.code | Should -Be "1432"
            $status.status.formattedMessage.message | Should -Be "some status msg 1"
            $status.status.Status | Should -Be transitioning
            $status.status.substatus[0].name | Should -Be "some operation 1"
            $status.status.substatus[0].formattedMessage.message | Should -Be "sub-status message 1"
        }

        It "should retain previous sub-status while updating status" {
            Add-HandlerSubStatus -Code 1500 -Message "sub-status message 2" -operationName "some operation 2"
            $status = Get-HandlerStatus -SequenceNumber 1
            $status.status.code | Should -Be "1432"
            $status.status.formattedMessage.message | Should -Be "some status msg 1"
            $status.status.Status | Should -Be transitioning
            $status.status.substatus[0].name | Should -Be "some operation 1"
            $status.status.substatus[0].formattedMessage.message | Should -Be "sub-status message 1"
            $status.status.substatus[1].name | Should -Be "some operation 2"
            $status.status.substatus[1].formattedMessage.message | Should -Be "sub-status message 2"
        }

        It "should push sub-status message to buffer and then flush to file" {
            Add-HandlerSubStatus -Code 1500 -Message "sub-status message 3" -operationName "some operation 3" -SubStatus transitioning
            Add-HandlerSubStatus -Code 1500 -Message "sub-status message 4" -operationName "some operation 4" -SubStatus error
            Set-HandlerStatus -Code 3000 -Message "some status msg 3" -Status error
            $status = Get-HandlerStatus -SequenceNumber 1
            $status.status.code | Should -Be "3000"
            $status.status.formattedMessage.message | Should -Be "some status msg 3"
            $status.status.Status | Should -Be error
            $status.status.substatus[0].name | Should -Be "some operation 1"
            $status.status.substatus[0].formattedMessage.message | Should -Be "sub-status message 1"
            $status.status.substatus[1].name | Should -Be "some operation 2"
            $status.status.substatus[1].formattedMessage.message | Should -Be "sub-status message 2"
            $status.status.substatus[2].name | Should -Be "some operation 3"
            $status.status.substatus[2].status | Should -Be transitioning
            $status.status.substatus[2].formattedMessage.message | Should -Be 'sub-status message 3'
            $status.status.substatus[3].name | Should -Be "some operation 4"
            $status.status.substatus[3].status | Should -Be error
            $status.status.substatus[3].formattedMessage.message | Should -Be 'sub-status message 4'
        }
    }

    Context "Status file should be cleaned properly" {

        BeforeAll {
            Mock -ModuleName AzureExtensionHandler Read-HandlerEnvironmentFile { 
                $mockHandlerEnvironmentData = @(
                    @{  
                        handlerEnvironment = @{ 
                            logFolder = "TestDrive:\"
                            statusFolder = "TestDrive:\"
                        }
                        version = 1
                    }
                )

                return ,$mockHandlerEnvironmentData
            }
            $statusFilePath = "TestDrive:\\1.status"
            Set-Content $statusFilePath -value "some garbage value"
        }

        It "should have correct status and sub-status properties" {
            Get-HandlerEnvironment -Refresh
            Clear-StatusFile
            (Get-Content $statusFilePath) -eq $null | Should -Be $true
        }
    }
}

Describe "Extension log file tests" {
    Context "Extension log should created properly" {

        BeforeAll {

            Mock -ModuleName AzureExtensionHandler Read-HandlerEnvironmentFile { 
                $mockHandlerEnvironmentData = @(
                    @{  
                        handlerEnvironment = @{ 
                            logFolder = "TestDrive:\logs"
                            statusFolder = "TestDrive:\"
                        }
                        version = 1
                    }
                )

                return ,$mockHandlerEnvironmentData
            }

            Mock -ModuleName AzureExtensionHandler Get-Date { return "date" }
            New-item -Name logs -Path TestDrive:\ -ItemType Directory
            $testPath1 = "TestDrive:\\1.settings"
            Set-Content $testPath1 -value "my test text." 
        }

        It "should create log file in correct location with correct name format" {
            Get-HandlerEnvironment -Refresh
            Initialize-ExtensionLogFile
            Test-Path TestDrive:\logs\RMExtensionHandler.1.date.log
        }
    }
}

Describe "Last sequence number tests" {
    Context "Last sequence number should be saved correctly" {

        BeforeAll {
            Mock -ModuleName AzureExtensionHandler Get-HandlerExecutionSequenceNumber { return 2 }
            Mock -ModuleName AzureExtensionHandler Get-LastSequenceNumberFilePath { return "TestDrive:\LASTSEQNUM" }
            Remove-Item TestDrive:\LASTSEQNUM -Force -ErrorAction SilentlyContinue
        }

        It "should correctly create file with proper sequence number" {
            Set-LastSequenceNumber
            Test-Path TestDrive:\LASTSEQNUM
            Get-Content TestDrive:\LASTSEQNUM | Should -Be 2
        }
    }

    Context "Last sequence number should be read correctly" {

        BeforeAll {
            Mock -ModuleName AzureExtensionHandler Get-LastSequenceNumberFilePath { return "TestDrive:\LASTSEQNUM" }
            New-Item -ItemType File -Path TestDrive:\LASTSEQNUM -Value 3 -Force -ErrorAction SilentlyContinue
        }

        It "should correctly create file with proper sequence number" {
            Get-LastSequenceNumber
            Test-Path TestDrive:\LASTSEQNUM
            Get-Content TestDrive:\LASTSEQNUM | Should -Be 3
        }
    }
}
