function Create-ClassicStorageAccount {
    param([string][Parameter(Mandatory = $true)]$subscriptionId,
        [string][Parameter(Mandatory = $true)]$storageAccountName,
        [System.Security.Cryptography.X509Certificates.X509Certificate2][Parameter(Mandatory = $true)]$certificate)

    $uri = "https://management.core.windows.net/$subscriptionId/services/storageservices"
    $label = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($storageAccountName))
    $bodyxml = [xml]$ExecutionContext.InvokeCommand.ExpandString(('<?xml version="1.0" encoding="utf-8"?>
  <CreateStorageServiceInput xmlns="http://schemas.microsoft.com/windowsazure">
  <ServiceName>$storageAccountName</ServiceName>
  <Label>$label</Label>
  <Location>South Central US</Location>
  <ExtendedProperties>
    <ExtendedProperty>
      <Name>ResourceGroup</Name>
      <Value>$storageAccountName</Value>
    </ExtendedProperty>
    <ExtendedProperty>
      <Name>ResourceLocation</Name>
      <Value>southcentralus</Value>
    </ExtendedProperty>
  </ExtendedProperties>
  <AccountType>Standard_LRS</AccountType>
            </CreateStorageServiceInput>'))
    Invoke-RestMethod -Method POST -Uri $uri -Certificate $certificate -Headers @{'x-ms-version' = '2014-08-01'; "Content-Type" = "application/xml"} -Body $bodyxml.OuterXml
    $getUri = "https://management.core.windows.net/$subscriptionId/services/storageservices/$storageAccountName"
    try {
        Invoke-RestMethod -Method GET -Uri $getUri -Certificate $certificate -Headers @{'x-ms-version' = '2014-08-01'}
    }
    catch {
        throw (Get-VstsLocString -Key "VMExtPIR_StorageAccountCreationError" -ArgumentList $_)
    }
}

function Ensure-StorageAccountExists {
    param([string][Parameter(Mandatory = $true)]$subscriptionId,
        [string][Parameter(Mandatory = $true)]$storageAccountName,
        [System.Security.Cryptography.X509Certificates.X509Certificate2][Parameter(Mandatory = $true)]$certificate)
    
    try {
        $uri = "https://management.core.windows.net/$subscriptionId/services/storageservices/$storageAccountName"
        $result = Invoke-RestMethod -Method GET -Uri $uri -Certificate $certificate -Headers @{'x-ms-version' = '2014-08-01'}
    }
    catch {
        if ($_.ErrorDetails.Message.Contains("ResourceNotFound")) {
            Create-ClassicStorageAccount -subscriptionId $subscriptionId -storageAccountName $storageAccountName -certificate $certificate
        }
        else {
            throw (Get-VstsLocString -Key "VMExtPIR_StorageDetailsFetchError" -ArgumentList $_)
        }

    }
}


function Ensure-ContainerExists {
    param([string][Parameter(Mandatory = $true)]$storageAccountName,
        [string][Parameter(Mandatory = $true)]$containerName,
        [string][Parameter(Mandatory = $true)]$storageAccountKey)

    $method = "GET"
    $headerDate = '2017-04-17'
    $headers = @{"x-ms-version" = "$headerDate"}
    $Url = "https://${storageAccountName}.blob.core.windows.net/${containerName}?restype=container"
    $xmsdate = (get-date -format r).ToString()
    $headers.Add("x-ms-date", $xmsdate)
    $signatureString = "${method}$([char]10)$([char]10)$([char]10)$([char]10)$([char]10)$([char]10)$([char]10)$([char]10)$([char]10)$([char]10)$([char]10)$([char]10)"
    #Add CanonicalizedHeaders
    $signatureString += "x-ms-date:" + $headers["x-ms-date"] + "$([char]10)"
    $signatureString += "x-ms-version:" + $headers["x-ms-version"] + "$([char]10)"
    $signatureString += "/${storageAccountName}/${containerName}$([char]10)"
    $signatureString += "restype:container"
    #Add CanonicalizedResource
    $uri = New-Object System.Uri -ArgumentList $Url
    $dataToMac = [System.Text.Encoding]::UTF8.GetBytes($signatureString)
    $accountKeyBytes = [System.Convert]::FromBase64String($storageAccountKey)
    $hmac = new-object System.Security.Cryptography.HMACSHA256((, $accountKeyBytes))
    $signature = [System.Convert]::ToBase64String($hmac.ComputeHash($dataToMac))
    $headers.Add("Authorization", "SharedKey " + $storageAccountName + ":" + $signature);
    $str = $headers | Out-String
    try {
        Invoke-RestMethod -Uri $Url -Method $method -headers $headers
    }
    catch {
        if ($_.ErrorDetails.Message.Contains("ContainerNotFound")) {
            Create-NewContainer -storageAccountName $storageAccountName -containerName $containerName -storageAccountKey $storageAccountKey
        }
        else {
            throw (Get-VstsLocString -Key "VMExtPIR_ContainerDetailsFetchError" -ArgumentList $_)
        }
    }
}

function Create-NewContainer {
    param([string][Parameter(Mandatory = $true)]$storageAccountName,
        [string][Parameter(Mandatory = $true)]$containerName,
        [string][Parameter(Mandatory = $true)]$storageAccountKey)

    $method = "PUT"
    $headerDate = '2017-04-17'
    $headers = @{"x-ms-version" = "$headerDate"}
    $Url = "https://${storageAccountName}.blob.core.windows.net/${containerName}?restype=container"
    $xmsdate = (get-date -format r).ToString()
    $headers.Add("x-ms-date", $xmsdate)
    $signatureString = "${method}$([char]10)$([char]10)$([char]10)$([char]10)$([char]10)$([char]10)$([char]10)$([char]10)$([char]10)$([char]10)$([char]10)$([char]10)"
    #Add CanonicalizedHeaders
    $signatureString += "x-ms-date:" + $headers["x-ms-date"] + "$([char]10)"
    $signatureString += "x-ms-version:" + $headers["x-ms-version"] + "$([char]10)"
    $signatureString += "/${storageAccountName}/${containerName}$([char]10)"
    $signatureString += "restype:container"
    #Add CanonicalizedResource
    $uri = New-Object System.Uri -ArgumentList $Url
    $dataToMac = [System.Text.Encoding]::UTF8.GetBytes($signatureString)
    $accountKeyBytes = [System.Convert]::FromBase64String($storageAccountKey)
    $hmac = new-object System.Security.Cryptography.HMACSHA256((, $accountKeyBytes))
    $signature = [System.Convert]::ToBase64String($hmac.ComputeHash($dataToMac))
    $headers.Add("Authorization", "SharedKey " + $storageAccountName + ":" + $signature);
    $str = $headers | Out-String
    try {
        Invoke-RestMethod -Uri $Url -Method $method -headers $headers
    }
    catch {
        throw (Get-VstsLocString -Key "VMExtPIR_ContainerCreationError" -ArgumentList $_)
    }
}

function Set-StorageBlobContent {
    param([string][Parameter(Mandatory = $true)]$storageAccountName,
        [string][Parameter(Mandatory = $true)]$containerName,
        [string][Parameter(Mandatory = $true)]$storageBlobName,
        [string][Parameter(Mandatory = $true)]$packagePath,
        [string][Parameter(Mandatory = $true)]$storageAccountKey)


    $method = "PUT"
    $headerDate = '2017-04-17'
    $headers = @{"x-ms-version" = "$headerDate"}
    $Url = "https://${storageAccountName}.blob.core.windows.net/${containerName}/${storageBlobName}"
    $xmsdate = (get-date -format r).ToString()
    $content = [System.IO.File]::ReadAllBytes("$packagePath")
    $item = Get-Item "$packagePath"
    $length = $item.Length
    $headers.Add("x-ms-date", $xmsdate)
    $headers.Add("x-ms-blob-type", "BlockBlob")
    $headers.Add("Content-Type", "application/zip, application/octet-stream")
    $headers.Add("Content-Length", "$length")
    $signatureString = "${method}$([char]10)$([char]10)$([char]10)$length$([char]10)$([char]10)application/zip, application/octet-stream$([char]10)$([char]10)$([char]10)$([char]10)$([char]10)$([char]10)$([char]10)x-ms-blob-type:BlockBlob$([char]10)"
    #Add CanonicalizedHeaders
    $signatureString += "x-ms-date:" + $headers["x-ms-date"] + "$([char]10)"
    $signatureString += "x-ms-version:" + $headers["x-ms-version"] + "$([char]10)"
    $signatureString += "/${storageAccountName}/${containerName}/${storageBlobName}"
    #Add CanonicalizedResource
    $uri = New-Object System.Uri -ArgumentList $Url
    $dataToMac = [System.Text.Encoding]::UTF8.GetBytes($signatureString)
    $accountKeyBytes = [System.Convert]::FromBase64String($storageAccountKey)
    $hmac = new-object System.Security.Cryptography.HMACSHA256((, $accountKeyBytes))
    $signature = [System.Convert]::ToBase64String($hmac.ComputeHash($dataToMac))
    $headers.Add("Authorization", "SharedKey " + $storageAccountName + ":" + $signature)
    $str = $headers | Out-String
    try {
        Invoke-RestMethod -Uri $Url -Method $method -headers $headers -Body $content
    }
    catch {
        throw (Get-VstsLocString -Key "VMExtPIR_BlobUploadError" -ArgumentList $_)
    }
}
