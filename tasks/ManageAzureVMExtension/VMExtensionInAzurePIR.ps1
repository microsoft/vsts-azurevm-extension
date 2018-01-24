Trace-VstsEnteringInvocation $MyInvocation
Import-VstsLocStrings "$PSScriptRoot\Task.json"

# Get inputs.
$connectedServiceName = Get-VstsInput -Name ConnectedServiceName -Require
$action = Get-VstsInput -Name Action -Require
$storageAccountName = Get-VstsInput -Name StorageAccountName
$containerName = Get-VstsInput -Name ContainerName
$storageBlobName = Get-VstsInput -Name StorageBlobName
$extensionPackagePath = Get-VstsInput -Name ExtensionPackage
$extensionDefinitionFilePath = Get-VstsInput -Name ExtensionDefinitionFile
$extensionName = Get-VstsInput -Name ExtensionName -Require
$publisherName = Get-VstsInput -Name Publisher -Require
$extensionVersion = Get-VstsInput -Name Version -Require

# Validate the script path and args do not contains new-lines. Otherwise, it will
# break invoking the script via Invoke-Expression.
if ($extensionDefinitionFilePath -match '[\r\n]' -or [string]::IsNullOrWhitespace($extensionDefinitionFilePath)) {
    throw (Get-VstsLocString -Key InvalidScriptPath0 -ArgumentList $extensionDefinitionFilePath)
}

# Initialize Azure.
Import-Module $PSScriptRoot\ps_modules\VstsAzureHelpers_
Initialize-Azure -azurePsVersion ""

function Get-ServiceEndpointDetails {
    param([string][Parameter(Mandatory = $true)]$connectedServiceName)
    
    $endpoint = Get-VstsEndpoint -Name $connectedServiceName
    return $endpoint
}

function Upload-ExtensionPackageToStorageBlob {
    param([string][Parameter(Mandatory = $true)]$storageAccountName,
        [string][Parameter(Mandatory = $true)]$containerName,
        [string][Parameter(Mandatory = $true)]$packagePath,
        [string][Parameter(Mandatory = $true)]$storageBlobName)

    try {
        Get-AzureStorageAccount -StorageAccountName $storageAccountName -ErrorAction Stop
    }
    catch {
        if ($_.Exception.Message.Contains("ResourceNotFound")) {
            New-AzureStorageAccount -StorageAccountName $storageAccountName -Location "South Central US"
        }
    }

    $key = Get-AzureStorageKey -StorageAccountName $storageAccountName
    $ctx = New-AzureStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $key.Primary

    try {
        Get-AzureStorageContainer -Name $containerName -Context $ctx -ErrorAction Stop
    }
    catch {
        if ($_.Exception.Message.Contains("Can not find the container")) {
            New-AzureStorageContainer -Name $containerName -Context $ctx
        }
    }
    
    Set-AzureStorageBlobContent -Container $containerName -File $packagePath -Blob $storageBlobName -Context $ctx -Force
}



function Edit-ExtensionDefinitionXML {
    param([string][Parameter(Mandatory = $true)]$extensionDefinitionFilePath,
        [string][Parameter(Mandatory = $true)]$mediaLink)

    [xml]$extensionFileDocument = Get-Content -Path $extensionDefinitionFilePath
    $extensionFileDocument.ExtensionImage.MediaLink = $mediaLink
    return $extensionFileDocument
}

function Create-ExtensionPackageInAzurePIR {
    param([xml][Parameter(Mandatory = $true)]$bodyxml,
        [X509Certificate2][Parameter(Mandatory = $true)]$certificate,
        [string][Parameter(Mandatory = $true)]$subscriptionId)

    Write-Host "Updating extension to version: $($bodyxml.ExtensionImage.Version)"

    $uri = "https://management.core.windows.net/$subscriptionId/services/extensions"
    Write-Host "uri: $uri"

    # invoke POST rest api to create the extension
    Invoke-RestMethod -Method POST -Uri $uri -Certificate $certificate -Headers @{'x-ms-version' = '2014-08-01'} -Body $bodyxml.OuterXml -ContentType application/xml

    # set this version as value for release variable 
    $newVersion = $bodyxml.ExtensionImage.Version
    $newVersionVariable = "NewVersion"
    Write-Host "##vso[task.setvariable variable=$newVersionVariable;]$newVersion"

}

function Invoke-WithRetry {
    param (
        [ScriptBlock] $retryCommand,
        [int] $retryInterval = 120,
        [int] $maxRetries = 60
    )

    $retryCount = 0
    $isExecutedSuccessfully = $false

    do {
        try {
            & $retryCommand
            $isExecutedSuccessfully = $true
            break
        }
        catch {
            Write-Host "Exception code: $($_.Exception.Response.StatusCode.ToString())"
            Write-Host $_

            if ($_.Exception.Response.StatusCode.ToString() -ne "Conflict") {
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

function Update-ExtensionPackageInAzurePIR {
    param([xml][Parameter(Mandatory = $true)]$bodyxml,
        [System.Security.Cryptography.X509Certificates.X509Certificate2][Parameter(Mandatory = $true)]$certificate,
        [string][Parameter(Mandatory = $true)]$subscriptionId)

    $certificate.Thumbprint
    Write-Host "Updating extension to version: $($bodyxml.ExtensionImage.Version)"

    $uri = "https://management.core.windows.net/$subscriptionId/services/extensions?action=update"
    Write-Host "uri: $uri"

    # invoke PUT rest api to update the extension
    
    Invoke-WithRetry -retryCommand {Invoke-RestMethod -Method PUT -Uri $uri -Certificate $certificate -Headers @{'x-ms-version' = '2014-08-01'} -Body $bodyxml.OuterXml -ContentType application/xml -ErrorAction SilentlyContinue}
           
    # set this version as value for release variable 
    $newVersion = $bodyxml.ExtensionImage.Version
    $newVersionVariable = "NewVersion"
    Write-Host "##vso[task.setvariable variable=$newVersionVariable;]$newVersion"
}

function Upload-ExtensionPackageToAzurePIR {
    param([string][Parameter(Mandatory = $true)]$subscriptionId,
        [string][Parameter(Mandatory = $true)]$storageAccountName,
        [string][Parameter(Mandatory = $true)]$containerName,
        [string][Parameter(Mandatory = $true)]$storageBlobName,
        [string][Parameter(Mandatory = $true)]$extensionDefinitionFilePath,
        [System.Security.Cryptography.X509Certificates.X509Certificate2][Parameter(Mandatory = $true)]$certificate,
        [string][Parameter(Mandatory = $true)]$extensionVersion)

    # read extension definition
    $mediaLink = "https://{0}.blob.core.windows.net/{1}/{2}" -f $storageAccountName, $containerName, $storageBlobName
    $bodyxml = Edit-ExtensionDefinitionXML -extensionDefinitionFilePath $extensionDefinitionFilePath -mediaLink $mediaLink
    Write-Host "Body xml: $bodyxml"

    if ($extensionVersion -eq "1.0.0.0") {
        Create-ExtensionPackageInAzurePIR -bodyxml $bodyxml -certificate $certificate -subscriptionId $subscriptionId
    }
    else {
        Update-ExtensionPackageInAzurePIR -bodyxml $bodyxml -certificate $certificate -subscriptionId $subscriptionId
    }
}

function Delete-ExtensionPackageFromAzurePIR {
    param([string][Parameter(Mandatory = $true)]$extensionName,
        [string][Parameter(Mandatory = $true)]$publisher,
        [string][Parameter(Mandatory = $true)]$versionToDelete,
        [System.Security.Cryptography.X509Certificates.X509Certificate2][Parameter(Mandatory = $true)]$certificate,
        [string][Parameter(Mandatory = $true)]$subscriptionId)

    if ($versionToDelete -eq "NOTHING_TO_DELETE") {
        Write-Host "No extension will be deleted"
        return
    }

    Write-Host "Deleting extension version: $versionToDelete"
    $certificate.Thumbprint

    # First set extension as internal and then delete
    [xml]$definitionXml = [xml]('<?xml version="1.0" encoding="utf-8"?>
  <ExtensionImage xmlns="http://schemas.microsoft.com/windowsazure" xmlns:i="http://www.w3.org/2001/XMLSchema-instance">   
  <ProviderNameSpace></ProviderNameSpace>
  <Type></Type>
  <Version></Version>
  <IsInternalExtension>true</IsInternalExtension>
  <IsJsonExtension>true</IsJsonExtension>
  </ExtensionImage>')

    $definitionXml.ExtensionImage.ProviderNameSpace = [string]$publisher
    $definitionXml.ExtensionImage.Type = [string]$extensionName
    $definitionXml.ExtensionImage.Version = [string]$versionToDelete
    $($definitionXml.ExtensionImage.version)

    $putUri = "https://management.core.windows.net/$subscriptionId/services/extensions?action=update"
    Write-Host "Updating extension to mark it as internal. using uri: $putUri"

    Invoke-WithRetry -retryCommand { Invoke-RestMethod -Method PUT -Uri $putUri -Certificate $certificate -Headers @{'x-ms-version' = '2014-08-01'} -Body $definitionXml -ContentType application/xml -ErrorAction SilentlyContinue }

    Start-Sleep -Seconds 10

    # now delete
    $uri = "https://management.core.windows.net/$subscriptionId/services/extensions/$publisher/$extensionName/$versionToDelete"
    Write-Host "Deleting extension. using uri: $uri"

    Invoke-WithRetry -retryCommand { Invoke-RestMethod -Method DELETE -Uri $uri -Certificate $certificate -Headers @{'x-ms-version' = '2014-08-01'} -ErrorAction SilentlyContinue }
}

$serviceEndpointDetails = Get-ServiceEndpointDetails -connectedServiceName $connectedServiceName

$bytes = [System.Convert]::FromBase64String($serviceEndpointDetails.Auth.parameters.certificate)
$certificate = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
$certificate.Import($bytes, $null, [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable)

if ($action -eq "Upload") {
    Upload-ExtensionPackageToStorageBlob -storageAccountName $storageAccountName -containerName $containerName -packagePath $extensionPackagePath -storageBlobName $storageBlobName
    Upload-ExtensionPackageToAzurePIR -subscriptionId $serviceEndpointDetails.Data.subscriptionId -storageAccountName $storageAccountName -containerName $containerName -storageBlobName $storageBlobName -extensionDefinitionFilePath $extensionDefinitionFilePath -certificate $certificate -extensionVersion $extensionVersion
}
elseif ($action -eq "Delete") {
    Delete-ExtensionPackageFromAzurePIR  -extensionName $extensionName -publisher $publisherName -versionToDelete $extensionVersion -certificate $certificate -subscriptionId $serviceEndpointDetails.Data.subscriptionId
}
else {
    throw (Get-VstsLocString -Key InvalidAction -ArgumentList $)
}


