BeforeAll {
    . "$PSScriptRoot\..\bin\ConfigSettingsReader.ps1"
}

Describe "parse pipelines integrity settings tests" {
    BeforeEach {
        $script:pipelinePublicSettings = @{
            isPipelinesAgent = $true
            agentDownloadUrl = "https://example.invalid/vsts-agent-win-x64.zip"
            agentFolder = "C:\agent"
            enableScriptDownloadUrl = "https://example.invalid/enableagent.ps1"
            enableScriptParameters = "-pool test"
        }

        Mock Write-Log {}
        Mock Add-HandlerSubStatus {}
        Mock Set-HandlerStatus {}
        Mock Invoke-WebRequest {}
        Mock Invoke-RestMethod {}
        Mock Get-HandlerSettings {
            return @{
                publicSettings = $script:pipelinePublicSettings
                protectedSettings = @{}
            }
        }
        Mock Set-ErrorStatusAndErrorExit {
            param($exception, $operationName)
            throw $exception
        }
    }

    It "uses legacy compatibility when integrityMode is absent" {
        $settings = Get-ConfigurationFromSettings

        $settings.IntegrityMode | Should -Be "legacy"
        $settings.AgentDownloadSha256 | Should -BeNullOrEmpty
        $settings.EnableScriptSha256 | Should -BeNullOrEmpty
        Assert-MockCalled Invoke-WebRequest -Times 0
        Assert-MockCalled Invoke-RestMethod -Times 0
    }

    It "accepts explicit legacy mode without hashes" {
        $script:pipelinePublicSettings.integrityMode = "LeGaCy"

        $settings = Get-ConfigurationFromSettings

        $settings.IntegrityMode | Should -Be "legacy"
    }

    It "accepts enforce mode case-insensitively with valid hashes" {
        $script:pipelinePublicSettings.integrityMode = "EnFoRcE"
        $script:pipelinePublicSettings.agentDownloadSha256 = "a" * 64
        $script:pipelinePublicSettings.enableScriptSha256 = "B" * 64

        $settings = Get-ConfigurationFromSettings

        $settings.IntegrityMode | Should -Be "enforce"
        $settings.AgentDownloadSha256 | Should -Be ("a" * 64)
        $settings.EnableScriptSha256 | Should -Be ("B" * 64)
    }

    It "rejects an invalid integrityMode value '<ValueDescription>'" -TestCases @(
        @{ Value = $null; ValueDescription = "null" }
        @{ Value = ""; ValueDescription = "empty" }
        @{ Value = " "; ValueDescription = "whitespace" }
        @{ Value = 17; ValueDescription = "wrong type" }
        @{ Value = "strict"; ValueDescription = "unknown" }
        @{ Value = " agentEnforce "; ValueDescription = "surrounding whitespace" }
    ) {
        param($Value, $ValueDescription)

        $script:pipelinePublicSettings.integrityMode = $Value

        { Get-ConfigurationFromSettings } | Should -Throw "*integrityMode*"
        Assert-MockCalled Invoke-WebRequest -Times 0
        Assert-MockCalled Invoke-RestMethod -Times 0
    }

    It "accepts agent-only mode case-insensitively without a script hash" {
        $script:pipelinePublicSettings.integrityMode = "AgEnTeNfOrCe"
        $script:pipelinePublicSettings.agentDownloadSha256 = "a" * 64

        $settings = Get-ConfigurationFromSettings

        $settings.IntegrityMode | Should -Be "agentenforce"
        $settings.AgentDownloadSha256 | Should -Be ("a" * 64)
        $settings.EnableScriptSha256 | Should -BeNullOrEmpty
    }

    It "passes '<HashName>' through without validating its format" -TestCases @(
        @{ HashName = "agentDownloadSha256"; Value = $null }
        @{ HashName = "agentDownloadSha256"; Value = "" }
        @{ HashName = "agentDownloadSha256"; Value = ("a" * 63) }
        @{ HashName = "agentDownloadSha256"; Value = ("g" * 64) }
        @{ HashName = "agentDownloadSha256"; Value = ("a" * 64) + "`n" }
        @{ HashName = "agentDownloadSha256"; Value = 123 }
        @{ HashName = "enableScriptSha256"; Value = $null }
        @{ HashName = "enableScriptSha256"; Value = "" }
        @{ HashName = "enableScriptSha256"; Value = ("b" * 65) }
        @{ HashName = "enableScriptSha256"; Value = ("z" * 64) }
        @{ HashName = "enableScriptSha256"; Value = ("b" * 64) + "`n" }
        @{ HashName = "enableScriptSha256"; Value = @("a" * 64) }
    ) {
        param($HashName, $Value)

        $script:pipelinePublicSettings.integrityMode = "enforce"
        $script:pipelinePublicSettings.agentDownloadSha256 = "a" * 64
        $script:pipelinePublicSettings.enableScriptSha256 = "b" * 64
        $script:pipelinePublicSettings[$HashName] = $Value

        $settings = Get-ConfigurationFromSettings

        $settings.IntegrityMode | Should -Be "enforce"
        $settings[$HashName] | Should -Be $Value
        Assert-MockCalled Invoke-WebRequest -Times 0
        Assert-MockCalled Invoke-RestMethod -Times 0
    }

    It "reads parameters from protected settings without logging them" {
        $script:pipelinePublicSettings.Remove("enableScriptParameters")
        Mock Get-HandlerSettings {
            @{
                publicSettings = $script:pipelinePublicSettings
                protectedSettings = @{ enableScriptParameters = "-token protected-test-token" }
            }
        }

        $settings = Get-ConfigurationFromSettings

        $settings.EnableScriptParameters | Should -Be "-token protected-test-token"
        Should -Invoke Write-Log -Times 0 -ParameterFilter { $message -like "*protected-test-token*" }
    }
}
