function Invoke-WithRetry {
    param (
        [ScriptBlock] $retryCommand,
        [int] $retryInterval = 120,
        [int] $maxRetries = 60,
        [string] $expectedErrorMessage = ""
    )

    $retryCount = 0
    $isExecutedSuccessfully = $false

    do {
        try {
            $scriptOutput = & $retryCommand
            $isExecutedSuccessfully = $true
            return $scriptOutput
        }
        catch {
            Write-Host "Exception code: $($_.Exception.Response.StatusCode.ToString())"
            Write-Host $_

            if (($expectedErrorMessage -eq "") -or ($_.Exception.Response.StatusCode.ToString() -ne $expectedErrorMessage)) {
                Write-Error "Failed with non-conflict error. No need to retry. Fail now."
                exit
            }
        }
    
        Write-Host "success: $isExecutedSuccessfully, retry count: $retryCount, max retries: $maxRetries. Will retry after $retryInterval seconds"
        $retryCount++
        Start-Sleep -s $retryInterval

    }
    While (($isExecutedSuccessfully -ne $true) -and ($retryCount -lt $maxRetries))

    if ($isExecutedSuccessfully -ne $true) {
        Write-Error "Could not execute command successfully. Failing with timeout."
        exit
    }
}
