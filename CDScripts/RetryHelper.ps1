function Invoke-WithRetry
{
    param (
        [ScriptBlock] $retryCommand,
        [int] $retryInterval = 120,
        [int] $maxRetries = 60
    )

    $retryCount = 0
    $isExecutedSuccessfully = $false

    do
    {
        try 
        {
            & $retryCommand
            $isExecutedSuccessfully = $true
            break
        }
        catch
        {
            Write-Host "Exception code: $($error[0].Exception.Response.StatusCode.ToString())"
            Write-Host $Error[0]

            if($error[0].Exception.Response.StatusCode.ToString() -ne "Conflict")
            {
                Write-Error "Failed with non-conflict error. No need to retry. Fail now."
                exit
            }
        }
    
        Write-Host "success: $isExecutedSuccessfully, retry count: $retryCount, max retries: $maxRetries. Will retry after $retryInterval seconds"
        $retryCount++
        Start-Sleep -s $retryInterval

    } While (($isExecutedSuccessfully -ne $true) -and ($retryCount -lt $maxRetries))

    if($isExecutedSuccessfully -ne $true)
    {
        Write-Error "Could not execute command successfully. Failing with timeout."
        exit
    }
}