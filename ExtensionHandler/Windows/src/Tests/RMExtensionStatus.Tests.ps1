$currentScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path

Import-Module "$currentScriptPath\..\bin\AzureExtensionHandler.psm1"
Import-Module "$currentScriptPath\..\bin\RMExtensionStatus.psm1"

Describe "Handler error status tests" {

    Context "Should set proper terminating error " {

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

        try
        {
            throw New-HandlerTerminatingError $RM_Extension_Status.ArchitectureNotSupported.Code -Message $RM_Extension_Status.ArchitectureNotSupported.Message
        }
        catch 
        {
            Set-HandlerErrorStatus $_
        } 

        $status = Get-HandlerStatus -SequenceNumber 1

        It "should have correct error details" {
            $status.status.code | Should Be $RM_Extension_Status.ArchitectureNotSupported.Code
            $status.status.Status | Should Be error
        }

        It "should have info about logs location" {
            $status.status.formattedMessage.message | Should BeLike 'The Extension failed to execute: The current CPU architecture is not supported. Deployment agent requires x64 architecture.*'
            $status.status.formattedMessage.message | Should BeLike "*More information about the failure can be found in the logs located under 'TestDrive:\' on the VM."
        }
    }
}
