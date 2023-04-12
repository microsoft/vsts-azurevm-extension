Describe "Ensure Net6 File Consistent Tests" {

    Context "The local copy of the net6.json file should be consistent with the original maintained in the azure-pipelines-agent repo" {
        It "should verify that local copy of net6.json is same as the original file maintained in the azure-pipelines-agent repo " {
            $local = (Get-Content "..\net6.json" -Raw) | ConvertFrom-Json
            $remote = Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure-pipelines-agent/master/src/Agent.Listener/net6.json" -UseBasicParsing | ConvertFrom-Json
            $diff = Compare-Object -ReferenceObject $local -DifferenceObject $remote
            $diff -eq $null | Should -Be $true
        }
    }
}