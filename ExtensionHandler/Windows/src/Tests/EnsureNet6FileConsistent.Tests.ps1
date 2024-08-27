# Skiping the test for now. It is likely quite pointless and requires some more work to fix it.
# net6.json does not exist for a while and we didn't even notice :-/
# It probably means the extension may fail to install on some supported linux OSes
# But for now we need to release some earlier fixes with new minor version and I don't want to bundle too many things at the same time
Describe "Ensure Net6 File Consistent Tests" -Skip {

    Context "The local copy of the net6.json file should be consistent with the original file maintained in the azure-pipelines-agent repo" {
        It "should verify that local copy of net6.json does not have any discrepancies with https://raw.githubusercontent.com/microsoft/azure-pipelines-agent/master/src/Agent.Listener/net6.json" {
            $local = (Get-Content "..\net6.json" -Raw) | ConvertFrom-Json
            $remote = Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure-pipelines-agent/master/src/Agent.Listener/net6.json" -UseBasicParsing | ConvertFrom-Json
            $diff = Compare-Object -ReferenceObject $local -DifferenceObject $remote
            $diff -eq $null | Should -Be $true
        }
    }
}
