Trace-VstsEnteringInvocation $MyInvocation
Import-VstsLocStrings "$PSScriptRoot\Task.json"

. $PSScriptRoot/StorageAccountOperations.ps1
. $PSScriptRoot/AzurePIROperations.ps1
. $PSScriptRoot/Utils.ps1

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

# Validate the extension definition file path does not contains new-lines. Otherwise, it will
# break invoking the script via Invoke-Expression.
if ($extensionDefinitionFilePath -match '[\r\n]' -or [string]::IsNullOrWhitespace($extensionDefinitionFilePath)) {
    throw (Get-VstsLocString -Key InvalidScriptPath0 -ArgumentList $extensionDefinitionFilePath)
}

# Initialize Azure.
Import-Module $PSScriptRoot\ps_modules\VstsAzureHelpers_
#Initialize-Azure -azurePsVersion ""

function Get-ServiceEndpointDetails {
    param([string][Parameter(Mandatory = $true)]$connectedServiceName)
    
    $endpoint = Get-VstsEndpoint -Name $connectedServiceName
    return $endpoint
}

function Update-MediaLink {
    param([string][Parameter(Mandatory = $true)]$extensionDefinitionFilePath,
        [string][Parameter(Mandatory = $true)]$mediaLink)

    [xml]$extensionFileDocument = Get-Content -Path $extensionDefinitionFilePath
    $extensionFileDocument.ExtensionImage.MediaLink = $mediaLink
    return $extensionFileDocument
}

function Upload-ExtensionPackageToStorageBlob {
    param([string][Parameter(Mandatory = $true)]$subscriptionId,
        [string][Parameter(Mandatory = $true)]$storageAccountName,
        [string][Parameter(Mandatory = $true)]$containerName,
        [string][Parameter(Mandatory = $true)]$packagePath,
        [string][Parameter(Mandatory = $true)]$storageBlobName,
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
            throw $_
        }
    }

    $keysUri = "https://management.core.windows.net/$subscriptionId/services/storageservices/$storageAccountName/keys"
    $keysResult = Invoke-RestMethod -Method GET -Uri $keysUri -Certificate $certificate -Headers @{'x-ms-version' = '2014-08-01'}
    $storageAccountKey = $keysResult.StorageService.StorageServiceKeys.Primary
    
    try {
        Get-ContainerDetails -storageAccountName $storageAccountName -containerName $containerName -storageAccountKey $storageAccountKey
    }
    catch {
        if ($_.ErrorDetails.Message.Contains("ContainerNotFound")) {
            Create-NewContainer -storageAccountName $storageAccountName -containerName $containerName -storageAccountKey $storageAccountKey
        }
        else {
            throw $_
        }
    }
    
    Set-StorageBlobContent -storageAccountName $storageAccountName -containerName $containerName -storageBlobName $storageBlobName -packagePath $packagePath -storageAccountKey $storageAccountKey
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
    $bodyxml = Update-MediaLink -extensionDefinitionFilePath $extensionDefinitionFilePath -mediaLink $mediaLink
    Write-Host "Body xml: $bodyxml"
    
    $extensionExistsInPIR = $false
    $extensionExistsInPIR = Check-ExtensionExistsInAzurePIR -subscriptionId $subscriptionId -certificate $certificate -publisher $bodyxml.ExtensionImage.ProviderNameSpace -type $bodyxml.ExtensionImage.Type
    if ($extensionExistsInPIR) {
        Update-ExtensionPackageInAzurePIR -bodyxml $bodyxml -certificate $certificate -subscriptionId $subscriptionId
    }
    else {
        $bodyxml.ExtensionImage.Version = "1.0.0.0"
        Create-ExtensionPackageInAzurePIR -bodyxml $bodyxml -certificate $certificate -subscriptionId $subscriptionId
    }
}


$serviceEndpointDetails = Get-ServiceEndpointDetails -connectedServiceName $connectedServiceName

$bytes = [System.Convert]::FromBase64String($serviceEndpointDetails.Auth.parameters.certificate)
$certificate = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
$certificate.Import($bytes, $null, [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable)

if ($action -eq "Upload") {
    Upload-ExtensionPackageToStorageBlob -subscriptionId $serviceEndpointDetails.Data.subscriptionId -storageAccountName $storageAccountName -containerName $containerName -packagePath $extensionPackagePath -storageBlobName $storageBlobName -certificate $certificate
    Upload-ExtensionPackageToAzurePIR -subscriptionId $serviceEndpointDetails.Data.subscriptionId -storageAccountName $storageAccountName -containerName $containerName -storageBlobName $storageBlobName -extensionDefinitionFilePath $extensionDefinitionFilePath -certificate $certificate -extensionVersion $extensionVersion
}
elseif ($action -eq "Delete") {
    Delete-ExtensionPackageFromAzurePIR  -extensionName $extensionName -publisher $publisherName -versionToDelete $extensionVersion -certificate $certificate -subscriptionId $serviceEndpointDetails.Data.subscriptionId
}
else {
    throw (Get-VstsLocString -Key InvalidAction -ArgumentList $)
}


