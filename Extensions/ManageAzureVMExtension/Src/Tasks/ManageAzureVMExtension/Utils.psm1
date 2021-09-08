function Construct-RestMethodBlock {
    param (
        [string] $uri,
        [string] $method,
        [object] $body,
        [IDictionary] $headers
    )

    if($proxyConfig -and ($proxyConfig.Contains("ProxyUrl")))
    {
        if($proxyConfig.Contains("ProxyAuthenticated") -and ($proxyConfig["ProxyAuthenticated"]))
        {
            $username = $proxyConfig["ProxyUserName"]
            $password = ConvertTo-SecureString -String $proxyConfig["ProxyPassword"] -AsPlainText -Force
            $credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $username, $password
            return {Invoke-RestMethod -Uri $uri -Method $method -Body $body -Headers $headers -Proxy $proxyConfig["ProxyUrl"] -ProxyCredential $credential}
        }
        else
        {
            return {Invoke-RestMethod -Uri $uri -Method $method -Body $body -Headers $headers -Proxy $proxyConfig["ProxyUrl"]}
        }
    }
    else
    {
        return {Invoke-RestMethod -Uri $uri -Method $method -Body $body -Headers $headers}
    }
}

function Construct-WebRequestBlock {
    param (
        [string] $uri,
        [string] $method,
        [object] $body,
        [IDictionary] $headers
    )

    if($proxyConfig -and ($proxyConfig.Contains("ProxyUrl")))
    {
        if($proxyConfig.Contains("ProxyAuthenticated") -and ($proxyConfig["ProxyAuthenticated"]))
        {
            $username = $proxyConfig["ProxyUserName"]
            $password = ConvertTo-SecureString -String $proxyConfig["ProxyPassword"] -AsPlainText -Force
            $credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $username, $password
            return {Invoke-WebRequest -Uri $uri -Method $method -Body $body -Headers $headers -Proxy $proxyConfig["ProxyUrl"] -ProxyCredential $credential -MaximumRedirection 0 -ErrorAction Ignore -UseBasicParsing}
        }
        else
        {
            return {Invoke-WebRequest -Uri $uri -Method $method -Body $body -Headers $headers -Proxy $proxyConfig["ProxyUrl"] -MaximumRedirection 0 -ErrorAction Ignore -UseBasicParsing}
        }
    }
    else
    {
        return {Invoke-WebRequest -Uri $uri -Method $method -Body $body -Headers $headers -MaximumRedirection 0 -ErrorAction Ignore -UseBasicParsing}
    }
}

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
            Write-Host (Get-VstsLocString -Key "VMExtPIR_ExceptionDetails" -ArgumentList $($_.Exception.Response.StatusCode.ToString()), $_)
            if (($expectedErrorMessage -eq "") -or ($_.Exception.Response.StatusCode.ToString() -ne $expectedErrorMessage)) {
                throw (Get-VstsLocString -Key "VMExtPIR_NonConflictErrorFail" -ArgumentList $_)
            }
        }
    
        Write-Host (Get-VstsLocString -Key "VMExtPIR_ExecutionStats" -ArgumentList $isExecutedSuccessfully, $retryCount, $maxRetries, $retryInterval)
        $retryCount++
        Start-Sleep -s $retryInterval

    }
    While (($isExecutedSuccessfully -ne $true) -and ($retryCount -lt $maxRetries))

    if ($isExecutedSuccessfully -ne $true) {
        throw (Get-VstsLocString -Key "VMExtPIR_FailWithTimeout")
    }
}

function Get-TimeSinceEpoch {
    $epochTime = Get-Date "01/01/1970"
    $currentTime = Get-Date
    $timeSinceEpoch = (New-TimeSpan -Start $epochTime -End $currentTime).Ticks
    return $timeSinceEpoch
}

function Download-File{
    param (
        [string] $downloadUrl,
        [string] $target
    )

    $WebClient = New-Object System.Net.WebClient
    if($proxyConfig -and ($proxyConfig.Contains("ProxyUrl")))
    {
        $WebProxy = New-Object System.Net.WebProxy($proxyConfig["ProxyUrl"], $true)
        if($proxyConfig.Contains("ProxyAuthenticated") -and ($proxyConfig["ProxyAuthenticated"]))
        {
            $WebProxy.Credentials = New-Object System.Net.NetworkCredential($proxyConfig["ProxyUserName"], $proxyConfig["ProxyPassword"])
            $WebClient.Proxy = $WebProxy
        }
    }
    $WebClient.DownloadFile($downloadUrl, $target)

}

#
# Exports
#
Export-ModuleMember `
    -Function `
        Invoke-WithRetry, `
        Get-TimeSinceEpoch, `
        Construct-RestMethodBlock, `
        Construct-WebRequestBlock, `
        Download-File