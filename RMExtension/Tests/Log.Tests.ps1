$currentScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path

Import-Module "$currentScriptPath\..\bin\AzureExtensionHandler.psm1"
Import-Module "$currentScriptPath\..\bin\Log.psm1"

Describe "Log tests" {

    Context "Should log messages to file " {

        Mock -ModuleName AzureExtensionHandler Add-HandlerLogMessage

        Write-Log "some message"

        It "should call Add-HandlerLogMessages with correct parameter" {
            Assert-MockCalled -ModuleName AzureExtensionHandler Add-HandlerLogMessage -Times 1 -ParameterFilter { $Message.EndsWith("some message") }
        }
    }
}
