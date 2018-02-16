Trace-VstsEnteringInvocation $MyInvocation
Import-VstsLocStrings "$PSScriptRoot\Task.json"

. $PSScriptRoot/Constants.ps1
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
$extensionName = Get-VstsInput -Name ExtensionName
$publisherName = Get-VstsInput -Name Publisher
$extensionVersion = Get-VstsInput -Name Version

# Validate the extension definition file path does not contains new-lines. Otherwise, it will
# break invoking the script via Invoke-Expression.
if (-not([string]::IsNullOrWhitespace($extensionDefinitionFilePath)) -and $extensionDefinitionFilePath -match '[\r\n]') {
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

    Ensure-StorageAccountExists -subscriptionId $subscriptionId -storageAccountName $storageAccountName -certificate $certificate
    $storageAccountKey = Get-PrimaryStorageAccountKey -subscriptionId $subscriptionId -storageAccountName $storageAccountName -certificate $certificate
    Ensure-ContainerExists -storageAccountName $storageAccountName -containerName $containerName -storageAccountKey $storageAccountKey
    Set-StorageBlobContent -storageAccountName $storageAccountName -containerName $containerName -storageBlobName $storageBlobName -packagePath $packagePath -storageAccountKey $storageAccountKey
}

function Upload-ExtensionPackageToAzurePIR {
    param([string][Parameter(Mandatory = $true)]$subscriptionId,
        [string][Parameter(Mandatory = $true)]$storageAccountName,
        [string][Parameter(Mandatory = $true)]$containerName,
        [string][Parameter(Mandatory = $true)]$storageBlobName,
        [string][Parameter(Mandatory = $true)]$extensionDefinitionFilePath,
        [System.Security.Cryptography.X509Certificates.X509Certificate2][Parameter(Mandatory = $true)]$certificate)

    # read extension definition
    $mediaLink = "https://{0}.blob.core.windows.net/{1}/{2}" -f $storageAccountName, $containerName, $storageBlobName
    $bodyxml = Update-MediaLink -extensionDefinitionFilePath $extensionDefinitionFilePath -mediaLink $mediaLink
    Write-Host "Body xml: {0}" -format $bodyxml
    
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
    Write-Host (Get-VstsLocString -Key "VMExtPIR_BlobUploadSuccess")
    Upload-ExtensionPackageToAzurePIR -subscriptionId $serviceEndpointDetails.Data.subscriptionId -storageAccountName $storageAccountName -containerName $containerName -storageBlobName $storageBlobName -extensionDefinitionFilePath $extensionDefinitionFilePath -certificate $certificate
    Write-Host (Get-VstsLocString -Key "VMExtPIR_PIRUploadSuccess")
}
elseif ($action -eq "Delete") {
    Delete-ExtensionPackageFromAzurePIR  -extensionName $extensionName -publisher $publisherName -versionToDelete $extensionVersion -certificate $certificate -subscriptionId $serviceEndpointDetails.Data.subscriptionId
    Write-Host (Get-VstsLocString -Key "VMExtPIR_PIRDeleteSuccess")
}
else {
    throw (Get-VstsLocString -Key "VMExtPIR_InvalidAction" -ArgumentList $action)
}