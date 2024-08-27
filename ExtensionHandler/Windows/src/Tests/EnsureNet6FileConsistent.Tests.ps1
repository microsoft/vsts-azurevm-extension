Describe "Ensure Net6 File Consistent Tests" {

    Context "The local copy of the net8.json file should be consistent with the original file maintained in the azure-pipelines-agent repo" {
        It "should verify that local copy of net8.json does not have any discrepancies with https://raw.githubusercontent.com/microsoft/azure-pipelines-agent/master/src/Agent.Listener/net8.json" {
            $local = (Get-Content "..\net8.json" -Raw) | ConvertFrom-Json
            $remote = Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure-pipelines-agent/master/src/Agent.Listener/net8.json" -UseBasicParsing | ConvertFrom-Json
            $diff = Compare-Object -ReferenceObject $local -DifferenceObject $remote
            $diff -eq $null | Should -Be $true
        }
    }
}
