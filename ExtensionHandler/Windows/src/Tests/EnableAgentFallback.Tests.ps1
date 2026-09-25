BeforeAll {
    Import-Module "$PSScriptRoot\..\bin\AzureExtensionHandler.psm1"
    Import-Module "$PSScriptRoot\..\bin\RMExtensionStatus.psm1"
    Import-Module "$PSScriptRoot\..\bin\RMExtensionCommon.psm1"
    Import-Module "$PSScriptRoot\..\bin\Log.psm1"
    . "$PSScriptRoot\..\bin\ConfigSettingsReader.ps1"
    . "$PSScriptRoot\..\bin\EnablePipelinesAgent.ps1"
}

AfterAll {
    # Clean up script.log file created during tests
    $logFile = Join-Path $PSScriptRoot "script.log"
    if (Test-Path $logFile) {
        Remove-Item $logFile -Force
    }
}

Describe "EnablePipelinesAgent fallback script tests" {
    Context "Should use bundled fallback script when storage download fails" {
        BeforeAll {
            # Fallback mechanism for enableagent script retrieval:
            # - Agent is on a CDN (vstsagenttools CDN) - typically reliable
            # - Enable script is on vstsagenttools storage account - can be inaccessible during outages
            # Fallback uses bundled copy of enable script when storage account is unreachable
            
            Mock Write-Log {}
            Mock Add-HandlerSubStatus {}
            Mock Set-ErrorStatusAndErrorExit { throw "Test failed" }
            Mock Set-Content {}
            Mock New-Item {}
            Mock Verify-InputNotNull {}
            Mock Get-Content { return "Mock log content" }
            Mock Start-Sleep {}
            Mock Set-HandlerStatus {}
            Mock Exit-WithCode {}
            Mock Set-LastSequenceNumber {}
            
            Mock Download-File { 
                param($downloadUrl, $target)
                # Agent download (CDN) succeeds
                if ($downloadUrl -like "*agent*.zip*") { return }
                # Enable script download (vstsagenttools storage) fails - simulating outage
                throw "Download failed - vstsagenttools storage account inaccessible" 
            }
            
            $script:agentFileCheckCount = 0
            Mock Test-Path { 
                param($Path)
                if ($Path -like "*MockAgentFolder\.agent") { 
                    $script:agentFileCheckCount++
                    return ($script:agentFileCheckCount -gt 1)
                }
                if ($Path -like "*\bin\enableagent.ps1") { return $true }
                if ($Path -like "*script.log") { return $false }
                if ($Path -like "*MockAgentFolder") { return $false }
                # Pass through to real Test-Path for non-mocked paths (e.g., Pester infrastructure)
                & (Get-Command Test-Path -CommandType Cmdlet) -Path $Path
            }
            
            Mock Start-Process { 
                return New-Object PSObject -Property @{ HasExited = $true }
            }
        }

        It "should set VSTS_AGENT_VMEXT_FALLBACK_USED environment variable when fallback is used" {
            $env:VSTS_AGENT_VMEXT_FALLBACK_USED = $null
            
            EnablePipelinesAgent @{
                AgentFolder = "C:\MockAgentFolder"
                AgentDownloadUrl = "http://fake.url/agent.zip"
                EnableScriptDownloadUrl = "http://invalid.url/enableagent.ps1"
                EnableScriptParameters = "-param1 value1"
            }
            
            $env:VSTS_AGENT_VMEXT_FALLBACK_USED | Should -Be "true"
        }

        It "should attempt to download from storage before using fallback" {
            Assert-MockCalled Download-File -Times 3 -Scope Context -ParameterFilter {
                $downloadUrl -like "*enableagent.ps1"
            }
        }

        It "should check for bundled script at PSScriptRoot\enableagent.ps1 when download fails" {
            Assert-MockCalled Test-Path -Times 1 -Scope Context -ParameterFilter { 
                $Path -like "*\bin\enableagent.ps1"
            }
        }

        It "should call Start-Process to execute bundled script" {
            Assert-MockCalled Start-Process -Times 1 -Scope Context
        }
    }

    Context "Should NOT use fallback when storage download succeeds" {
        BeforeAll {
            # When vstsagenttools storage account is accessible, use downloaded enable script normally
            # No fallback needed
            
            Mock Write-Log {}
            Mock Add-HandlerSubStatus {}
            Mock Set-ErrorStatusAndErrorExit { throw "Test failed" }
            Mock Set-Content {}
            Mock New-Item {}
            Mock Verify-InputNotNull {}
            Mock Get-Content { return "Mock log content" }
            Mock Start-Sleep {}
            Mock Download-File { return }
            Mock Set-HandlerStatus {}
            Mock Exit-WithCode {}
            Mock Set-LastSequenceNumber {}
            
            $script:agentFileCheckCount = 0
            Mock Test-Path { 
                param($Path)
                if ($Path -like "*MockAgentFolder\.agent") { 
                    $script:agentFileCheckCount++
                    return ($script:agentFileCheckCount -gt 1)
                }
                if ($Path -like "*script.log") { return $false }
                if ($Path -like "*MockAgentFolder") { return $false }
                # Pass through to real Test-Path for non-mocked paths (e.g., Pester infrastructure)
                & (Get-Command Test-Path -CommandType Cmdlet) -Path $Path
            }
            
            Mock Start-Process { 
                return New-Object PSObject -Property @{ HasExited = $true }
            }
        }

        It "should NOT set VSTS_AGENT_VMEXT_FALLBACK_USED when download succeeds" {
            $env:VSTS_AGENT_VMEXT_FALLBACK_USED = $null
            
            EnablePipelinesAgent @{
                AgentFolder = "C:\MockAgentFolder"
                AgentDownloadUrl = "http://fake.url/agent.zip"
                EnableScriptDownloadUrl = "http://storage.url/enableagent.ps1"
                EnableScriptParameters = "-param1 value1"
            }
            
            $env:VSTS_AGENT_VMEXT_FALLBACK_USED | Should -BeNullOrEmpty
        }

        It "should NOT check for bundled script when download succeeds" {
            Assert-MockCalled Test-Path -Times 0 -Scope Context -ParameterFilter { 
                $Path -like "*enableagent.ps1"
            }
        }

        It "should successfully download from storage" {
            Assert-MockCalled Download-File -Times 1 -Scope Context -ParameterFilter {
                $downloadUrl -like "*enableagent.ps1"
            }
        }
    }
}

Describe "EnablePipelinesAgent opt-in integrity" {
    BeforeEach {
        $script:config = @{
            IntegrityMode = "enforce"
            AgentFolder = "C:\MockAgentFolder"
            AgentDownloadUrl = "https://mirror.invalid/packages/vsts-agent-win-x64-1.2.3.zip"
            AgentDownloadSha256 = "a" * 64
            EnableScriptDownloadUrl = "https://other-mirror.invalid/bootstrap.ps1"
            EnableScriptSha256 = "B" * 64
            EnableScriptParameters = "-pool test"
        }
        $script:started = $false
        $script:extractedAgent = $false
        $script:bundled = $true
        $script:agentHash = "a" * 64
        $script:scriptHash = "b" * 64
        $script:bundleHash = "b" * 64
        $script:savedFallback = $env:VSTS_AGENT_VMEXT_FALLBACK_USED
        $env:VSTS_AGENT_VMEXT_FALLBACK_USED = $null
        Mock Write-Log {}
        Mock Add-HandlerSubStatus {}
        Mock Set-ErrorStatusAndErrorExit {
            param($exception, $operationName)
            throw $exception
        }
        Mock Set-Content {}
        Mock New-Item {}
        Mock Get-Content { "Mock log content" }
        Mock Start-Sleep {}
        Mock Set-HandlerStatus {}
        Mock Exit-WithCode {}
        Mock Set-LastSequenceNumber {}
        Mock Download-File {}
        Mock Copy-Item {}
        Mock Test-Path {
            param($Path, $LiteralPath)
            if ($PSBoundParameters.ContainsKey("LiteralPath")) { $Path = $LiteralPath }
            if ($Path -eq "C:\MockAgentFolder\.agent") { return $script:started }
            if ($Path -eq "C:\MockAgentFolder\bin\Agent.Listener.exe") { return $script:extractedAgent }
            if ($Path -like "*\bin\enableagent.ps1") { return $script:bundled }
            return $true
        }
        Mock Assert-PipelinesFileHash {
            param($Path, $ExpectedSha256)
            $hash = $script:scriptHash
            if ($Path -like "*.zip") {
                $hash = $script:agentHash
            }
            if ($Path -like "*\bin\enableagent.ps1") { $hash = $script:bundleHash }
            if ($ExpectedSha256 -isnot [string] -or
                -not [string]::Equals($hash, $ExpectedSha256, [StringComparison]::OrdinalIgnoreCase)) {
                throw "Hash verification failed for '$Path'."
            }
        }
        Mock Start-Process {
            $script:started = $true
            return [pscustomobject]@{ HasExited = $true }
        }
    }

    AfterEach {
        $env:VSTS_AGENT_VMEXT_FALLBACK_USED = $script:savedFallback
    }

    It "verifies each download once and preserves URL filenames" {
        EnablePipelinesAgent $script:config
        Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter {
            $ArgumentList -like "C:\MockAgentFolder\bootstrap.ps1 *"
        }
        Should -Invoke Download-File -Times 1 -Exactly -ParameterFilter {
            $downloadUrl -eq $script:config.AgentDownloadUrl -and $target -eq "C:\MockAgentFolder\vsts-agent-win-x64-1.2.3.zip"
        }
        Should -Invoke Download-File -Times 1 -Exactly -ParameterFilter {
            $downloadUrl -eq $script:config.EnableScriptDownloadUrl -and $target -eq "C:\MockAgentFolder\bootstrap.ps1"
        }
        Should -Invoke Assert-PipelinesFileHash -Times 2 -Exactly
        Should -Invoke Set-ErrorStatusAndErrorExit -Times 0
    }

    It "leaves explicit legacy downloads unverified" {
        $script:config.IntegrityMode = "legacy"
        $script:extractedAgent = $true
        $script:config.AgentDownloadUrl = "http://legacy.invalid/agent.zip"
        $script:config.EnableScriptDownloadUrl = "http://legacy.invalid/enableagent.ps1"
        $script:config.AgentDownloadSha256 = "invalid"
        $script:config.EnableScriptSha256 = $null
        EnablePipelinesAgent $script:config
        Should -Invoke Assert-PipelinesFileHash -Times 0
        Should -Invoke Start-Process -Times 1 -Exactly
    }

    It "rejects a mismatched <Key> through hash comparison" -ForEach @(
        @{ Key = "AgentDownloadSha256"; Value = $null; Downloads = 3 }
        @{ Key = "AgentDownloadSha256"; Value = ""; Downloads = 3 }
        @{ Key = "AgentDownloadSha256"; Value = ("a" * 63); Downloads = 3 }
        @{ Key = "AgentDownloadSha256"; Value = ("g" * 64); Downloads = 3 }
        @{ Key = "AgentDownloadSha256"; Value = ("a" * 64) + "`n"; Downloads = 3 }
        @{ Key = "AgentDownloadSha256"; Value = ("a" * 64) + [char]0; Downloads = 3 }
        @{ Key = "AgentDownloadSha256"; Value = 123; Downloads = 3 }
        @{ Key = "AgentDownloadSha256"; Value = @("a" * 64); Downloads = 3 }
        @{ Key = "EnableScriptSha256"; Value = $null; Downloads = 4 }
        @{ Key = "EnableScriptSha256"; Value = ""; Downloads = 4 }
        @{ Key = "EnableScriptSha256"; Value = ("b" * 65); Downloads = 4 }
        @{ Key = "EnableScriptSha256"; Value = ("z" * 64); Downloads = 4 }
        @{ Key = "EnableScriptSha256"; Value = ("b" * 64) + "`n"; Downloads = 4 }
        @{ Key = "EnableScriptSha256"; Value = @("b" * 64); Downloads = 4 }
    ) {
        $script:config[$Key] = $Value
        { EnablePipelinesAgent $script:config } | Should -Throw "*Hash verification failed*"
        Should -Invoke Download-File -Times $Downloads -Exactly
        Should -Invoke Start-Process -Times 0
        Should -Invoke Copy-Item -Times 0
        Should -Invoke Set-ErrorStatusAndErrorExit -Times 1 -ParameterFilter {
            "$exception" -like "*Hash verification failed*"
        }
    }

    It "fails hash comparison when <Key> is absent" -ForEach @(
        @{ Key = "AgentDownloadSha256"; Downloads = 3 }
        @{ Key = "EnableScriptSha256"; Downloads = 4 }
    ) {
        $script:config.Remove($Key)
        { EnablePipelinesAgent $script:config } | Should -Throw "*Hash verification failed*"
        Should -Invoke Download-File -Times $Downloads -Exactly
        Should -Invoke Start-Process -Times 0
        Should -Invoke Set-ErrorStatusAndErrorExit -Times 1 -ParameterFilter {
            "$exception" -like "*Hash verification failed*"
        }
    }

    It "does not execute after a mismatched agent archive exhausts retries in <Mode>" -ForEach @(
        @{ Mode = "enforce" }
        @{ Mode = "agentenforce" }
    ) {
        $script:config.IntegrityMode = $Mode
        $script:agentHash = "c" * 64
        { EnablePipelinesAgent $script:config } | Should -Throw "*Hash verification failed*"
        Should -Invoke Download-File -Times 3 -Exactly
        Should -Invoke Start-Process -Times 0
        Should -Invoke Set-ErrorStatusAndErrorExit -Times 1
    }

    It "verifies only the agent in agent-only mode" -ForEach @(
        @{ ScriptHash = $null }
        @{ ScriptHash = "not-a-hash" }
    ) {
        $script:config.IntegrityMode = "agentenforce"
        $script:config.EnableScriptSha256 = $ScriptHash
        $script:scriptHash = "c" * 64
        EnablePipelinesAgent $script:config
        Should -Invoke Download-File -Times 2 -Exactly
        Should -Invoke Assert-PipelinesFileHash -Times 1 -Exactly -ParameterFilter { $Path -like "*.zip" }
        Should -Invoke Assert-PipelinesFileHash -Times 0 -ParameterFilter { $Path -like "*.ps1" }
        Should -Invoke Start-Process -Times 1 -Exactly
        Should -Invoke Set-ErrorStatusAndErrorExit -Times 0
    }

    It "rejects an invalid agent hash in agent-only mode" -ForEach @(
        @{ Hash = $null }
        @{ Hash = "" }
        @{ Hash = ("a" * 63) }
        @{ Hash = ("g" * 64) }
        @{ Hash = ("a" * 64) + "`n" }
        @{ Hash = 123 }
        @{ Hash = @("a" * 64) }
    ) {
        $script:config.IntegrityMode = "agentenforce"
        $script:config.AgentDownloadSha256 = $Hash
        { EnablePipelinesAgent $script:config } | Should -Throw "*Hash verification failed*"
        Should -Invoke Download-File -Times 3 -Exactly -ParameterFilter { $downloadUrl -eq $script:config.AgentDownloadUrl }
        Should -Invoke Download-File -Times 0 -ParameterFilter { $downloadUrl -eq $script:config.EnableScriptDownloadUrl }
        Should -Invoke Start-Process -Times 0
        Should -Invoke Set-ErrorStatusAndErrorExit -Times 1
    }

    It "requires the agent hash in agent-only mode" {
        $script:config.IntegrityMode = "agentenforce"
        $script:config.Remove("AgentDownloadSha256")
        { EnablePipelinesAgent $script:config } | Should -Throw "*Hash verification failed*"
        Should -Invoke Download-File -Times 3 -Exactly
        Should -Invoke Start-Process -Times 0
    }

    It "retains the unverified bundled fallback in agent-only mode" {
        $script:config.IntegrityMode = "agentenforce"
        $script:config.Remove("EnableScriptSha256")
        $script:bundleHash = "c" * 64
        Mock Download-File { throw "Network unavailable" } -ParameterFilter { $downloadUrl -eq $script:config.EnableScriptDownloadUrl }
        EnablePipelinesAgent $script:config
        Should -Invoke Download-File -Times 4 -Exactly
        Should -Invoke Assert-PipelinesFileHash -Times 1 -Exactly
        Should -Invoke Copy-Item -Times 0
        Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter { $ArgumentList -like "*\bin\enableagent.ps1 *" }
        $env:VSTS_AGENT_VMEXT_FALLBACK_USED | Should -Be "true"
    }

    It "verifies the fallback hash and runs it from the original bundled path" {
        $script:scriptHash = "c" * 64
        EnablePipelinesAgent $script:config
        Should -Invoke Download-File -Times 4 -Exactly
        Should -Invoke Assert-PipelinesFileHash -Times 5 -Exactly
        Should -Invoke Copy-Item -Times 0
        Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter {
            $ArgumentList -like "*\bin\enableagent.ps1 *"
        }
        $env:VSTS_AGENT_VMEXT_FALLBACK_USED | Should -Be "true"
    }

    It "reports a bundled script hash mismatch" {
        $script:scriptHash = "c" * 64
        $script:bundleHash = "d" * 64
        { EnablePipelinesAgent $script:config } | Should -Throw "*Hash verification failed*"
        Should -Invoke Copy-Item -Times 0
        Should -Invoke Start-Process -Times 0
        Should -Invoke Set-ErrorStatusAndErrorExit -Times 1
    }

    It "reports an error when the script download and bundle are unavailable" {
        $script:bundled = $false
        Mock Download-File { throw "Network unavailable" } -ParameterFilter { $downloadUrl -eq $script:config.EnableScriptDownloadUrl }
        { EnablePipelinesAgent $script:config } | Should -Throw "*Network unavailable*"
        Should -Invoke Start-Process -Times 0
        Should -Invoke Set-ErrorStatusAndErrorExit -Times 1
    }

    It "leaves archive selection to the bootstrap" {
        Mock Get-ChildItem { throw "Archive enumeration is not required." }
        EnablePipelinesAgent $script:config
        Should -Invoke Get-ChildItem -Times 0
        Should -Invoke Start-Process -Times 1 -Exactly
        Should -Invoke Set-ErrorStatusAndErrorExit -Times 0
    }

    It "preserves bootstrap resume behavior for an existing extracted agent in <Mode>" -ForEach @(
        @{ Mode = "enforce" }
        @{ Mode = "agentenforce" }
    ) {
        $script:config.IntegrityMode = $Mode
        $script:extractedAgent = $true
        EnablePipelinesAgent $script:config
        Should -Invoke Start-Process -Times 1 -Exactly
        Should -Invoke Set-ErrorStatusAndErrorExit -Times 0
    }

    It "reports an error if hashing the downloaded archive fails" {
        Mock Assert-PipelinesFileHash { throw "File unavailable" }
        { EnablePipelinesAgent $script:config } | Should -Throw "*File unavailable*"
        Should -Invoke Download-File -Times 3 -Exactly
        Should -Invoke Start-Process -Times 0
        Should -Invoke Set-ErrorStatusAndErrorExit -Times 1
    }

    It "keeps the existing already-configured skip in <Mode>" -ForEach @(
        @{ Mode = "enforce" }
        @{ Mode = "agentenforce" }
    ) {
        $script:config.IntegrityMode = $Mode
        $script:started = $true
        $script:extractedAgent = $true
        EnablePipelinesAgent $script:config
        Should -Invoke Download-File -Times 0
        Should -Invoke Assert-PipelinesFileHash -Times 0
        Should -Invoke Start-Process -Times 0
        Should -Invoke Exit-WithCode -Times 1 -Exactly
    }
}

Describe "Pipelines file hash verification" {
    BeforeAll {
        function Get-FileHash {}
    }

    BeforeEach {
        Mock Get-FileHash { throw "Get-FileHash is unavailable in PowerShell 3." }
    }

    It "checks real file bytes without modifying the file" {
        $path = Join-Path $PSScriptRoot "..\bin\EnablePipelinesAgent.ps1"
        $sha256 = [Security.Cryptography.SHA256]::Create()
        try {
            $expected = [BitConverter]::ToString($sha256.ComputeHash([IO.File]::ReadAllBytes($path))).Replace("-", "").ToLowerInvariant()
        } finally {
            $sha256.Dispose()
        }
        { Assert-PipelinesFileHash $path $expected } | Should -Not -Throw
        { Assert-PipelinesFileHash $path $expected.ToUpperInvariant() } | Should -Not -Throw
        { Assert-PipelinesFileHash $path ("0" * 64) } | Should -Throw "*Hash verification failed*"
        { Assert-PipelinesFileHash ($path + ".missing") $expected } | Should -Throw
        Should -Invoke Get-FileHash -Times 0
    }

    It "rejects malformed expected hashes using the real verifier" -ForEach @(
        @{ Hash = $null }
        @{ Hash = "" }
        @{ Hash = " " }
        @{ Hash = ("a" * 63) }
        @{ Hash = ("a" * 65) }
        @{ Hash = ("g" * 64) }
        @{ Hash = ("a" * 64) + "`n" }
        @{ Hash = ("a" * 64) + [char]0 }
        @{ Hash = 123 }
        @{ Hash = @("a" * 64) }
    ) {
        $path = Join-Path $PSScriptRoot "..\bin\EnablePipelinesAgent.ps1"
        { Assert-PipelinesFileHash $path $Hash } | Should -Throw "*Hash verification failed*"
        Should -Invoke Get-FileHash -Times 0
    }

    It "closes the file stream after successful and failed verification" {
        $path = [IO.Path]::GetTempFileName()
        try {
            [IO.File]::WriteAllText($path, "abc")
            Assert-PipelinesFileHash $path "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
            { Assert-PipelinesFileHash $path ("0" * 64) } | Should -Throw "*Hash verification failed*"
            $stream = [IO.File]::Open($path, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
            $stream.Dispose()
        } finally {
            [IO.File]::Delete($path)
        }
    }

    It "checks a fixed binary SHA-256 vector and detects a change after the first MiB" {
        [byte[]] $content = ([byte[]] @(0, 255, 13, 10) * (256 * 1024)) + [Text.Encoding]::ASCII.GetBytes("tail`n")
        # Same independently checked binary vector as the Linux hash tests.
        $expected = "009a4614f0b673f2fa8e5c3e03c51c11b61e5f9a888b6c37bc42cda525f501d5"
        $path = [IO.Path]::GetTempFileName()
        try {
            [IO.File]::WriteAllBytes($path, $content)
            { Assert-PipelinesFileHash $path $expected } | Should -Not -Throw
            $content[$content.Length - 1] = 120
            [IO.File]::WriteAllBytes($path, $content)
            { Assert-PipelinesFileHash $path $expected } | Should -Throw "*Hash verification failed*"
            Should -Invoke Get-FileHash -Times 0
        } finally {
            [IO.File]::Delete($path)
        }
    }
}
