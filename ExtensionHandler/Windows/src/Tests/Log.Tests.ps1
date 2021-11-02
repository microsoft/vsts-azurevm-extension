
BeforeAll {
    Import-Module "$PSScriptRoot\..\bin\AzureExtensionHandler.psm1"
    Import-Module "$PSScriptRoot\..\bin\Log.psm1"
}
Describe "Log tests" {
    Context "Should log messages to file " {

        BeforeAll {

            Mock -ModuleName AzureExtensionHandler Add-HandlerLogMessage
        }

        It "should call Add-HandlerLogMessages with correct parameter" {
            Write-Log "some message"
            Assert-MockCalled -ModuleName AzureExtensionHandler Add-HandlerLogMessage -Times 1 -ParameterFilter { $Message.EndsWith("some message") }
        }
    }
}
