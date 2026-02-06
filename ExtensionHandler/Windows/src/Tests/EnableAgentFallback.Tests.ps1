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
