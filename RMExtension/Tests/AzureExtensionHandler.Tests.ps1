$currentScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path

Import-Module "$currentScriptPath\..\bin\AzureExtensionHandler.psm1"
Import-Module "$currentScriptPath\..\bin\RMExtensionUtilities.psm1"

Describe "Handler environment tests" {

    Context "Should get settings from file correctly " {

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

        It "should return correct log folder" {
            $handlerEnvironment.logFolder | Should Be "E:\\work\\RM\\VMExtension\\RMExtension\\Logs"
        }

        It "should return correct config folder" {
            $handlerEnvironment.configFolder | Should Be "E:\\work\\RM\\VMExtension\\RMExtension\\RuntimeSettings"
        }
    }
}

Describe "Handler sequence number tests" {
    Context "Should detect sequence number correctly" {

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

        $seqNo = Get-HandlerExecutionSequenceNumber -Refresh

        It "should return correct sequence number" {
            $seqNo | Should Be "2"
        }
    }
}

Describe "Handler settings tests" {
    Context "Should read config settings from file" {

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

        $testPath1 = "TestDrive:\\1.settings"
        Set-Content $testPath1 -value "{ `
	                                    `"runtimeSettings`": [{ `
		                                    `"handlerSettings`": { `
			                                    `"publicSettings`": { `
				                                    `"VSTSAccountName`": `"mseng`", `
				                                    `"Pool`": `"biprasad`" `
			                                    } `
		                                    } `
	                                    }] `
                                      }" 

        $settings = Get-HandlerSettings -Refresh

        It "should return correct public settings" {
            $settings.publicSettings.VSTSAccountName | Should Be "mseng"
            $settings.publicSettings.Pool | Should Be "biprasad"
        }
    }
}

Describe "Handler status tests" {
    Context "Handler status and sub-status should be written and read in proper format" {

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
        Add-HandlerSubStatus -Code 1433 -Message "sub-status message 1" -operationName "some operation 1"

        $status = Get-HandlerStatus -SequenceNumber 1

        It "should have correct status and sub-status properties" {
            $status.status.code | Should Be "1432"
            $status.status.formattedMessage.message | Should Be "some status msg 1"
            $status.status.Status | Should Be transitioning
            $status.status.substatus[0].name | Should Be "some operation 1"
            $status.status.substatus[0].formattedMessage.message | Should Be "sub-status message 1"
        }

        Add-HandlerSubStatus -Code 1500 -Message "sub-status message 2" -operationName "some operation 2"

        $status = Get-HandlerStatus -SequenceNumber 1

        It "should retain previous sub-status while updating status" {
            $status.status.code | Should Be "1432"
            $status.status.formattedMessage.message | Should Be "some status msg 1"
            $status.status.Status | Should Be transitioning
            $status.status.substatus[0].name | Should Be "some operation 1"
            $status.status.substatus[0].formattedMessage.message | Should Be "sub-status message 1"
            $status.status.substatus[1].name | Should Be "some operation 2"
            $status.status.substatus[1].formattedMessage.message | Should Be "sub-status message 2"
        }

        Add-HandlerSubStatus -Code 1500 -Message "sub-status message 3" -operationName "some operation 3" -SubStatus transitioning
        Add-HandlerSubStatus -Code 1500 -Message "sub-status message 4" -operationName "some operation 4" -SubStatus error
        Set-HandlerStatus -Code 3000 -Message "some status msg 3" -Status error
        $status = Get-HandlerStatus -SequenceNumber 1

        It "should push sub-status message to buffer and then flush to file" {
            $status.status.code | Should Be "3000"
            $status.status.formattedMessage.message | Should Be "some status msg 3"
            $status.status.Status | Should Be error
            $status.status.substatus[0].name | Should Be "some operation 1"
            $status.status.substatus[0].formattedMessage.message | Should Be "sub-status message 1"
            $status.status.substatus[1].name | Should Be "some operation 2"
            $status.status.substatus[1].formattedMessage.message | Should Be "sub-status message 2"
            $status.status.substatus[2].name | Should Be "some operation 3"
            $status.status.substatus[2].status | Should Be transitioning
            $status.status.substatus[2].formattedMessage.message | Should Be 'sub-status message 3'
            $status.status.substatus[3].name | Should Be "some operation 4"
            $status.status.substatus[3].status | Should Be error
            $status.status.substatus[3].formattedMessage.message | Should Be 'sub-status message 4'
        }
    }

    Context "Status file should be cleaned properly" {

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

        Get-HandlerEnvironment -Refresh
        Clear-StatusFile

        It "should have correct status and sub-status properties" {
            (Get-Content $statusFilePath) -eq $null | Should Be $true
        }
    }
}

Describe "Extension log file tests" {
    Context "Extension log should created properly" {

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

        Get-HandlerEnvironment -Refresh
        Initialize-ExtensionLogFile

        It "should create log file in correct location with correct name format" {
            Test-Path TestDrive:\logs\RMExtensionHandler.1.date.log
        }
    }
}
