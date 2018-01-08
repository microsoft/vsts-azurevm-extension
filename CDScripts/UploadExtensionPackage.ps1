<#
.Synopsis
    Upload extension zip file to a blob. Creates a SAS token for this blob and then update blob path in extension definition xml file.
    Azure will download this zip from the public blob and will replicate it across its PIR
.Usage
    UploadExtensionPackage.ps1 -relativePackagePath "VM extension\RMExtension.zip" -relativeExtensionDefinitionPath relativeExtensionDefinitionPath -storageResourceGroup rmvmextensiontest -storageAccountName rmvmextensiontest -storageContainerName agentextension -storageBlobName RMExtension.zip
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$relativePackagePath,

    [Parameter(Mandatory=$true)]
    [string]$relativeExtensionDefinitionPath,

    [Parameter(Mandatory=$true)]
    [string]$storageResourceGroup,
    
    [Parameter(Mandatory=$true)]
    [string]$storageAccountName,
    
    [Parameter(Mandatory=$true)]
    [string]$storageContainerName,

    [Parameter(Mandatory=$true)]
    [string]$storageBlobName
)

$packagePath = $relativePackagePath
$definitionFile = $relativeExtensionDefinitionPath

if($env:SYSTEM_ARTIFACTSDIRECTORY -and $env:BUILD_DEFINITIONNAME)
{
    $artifactsDir = Join-Path $env:SYSTEM_ARTIFACTSDIRECTORY $env:BUILD_DEFINITIONNAME
    $packagePath = Join-Path $artifactsDir $relativePackagePath
    $definitionFile = Join-Path $artifactsDir $relativeExtensionDefinitionPath
}

$subscription = Get-AzureSubscription -Current -ExtendedDetails
$uri = "https://management.core.windows.net/$($subscription.SubscriptionId)/services/storageservices/$storageAccountName/keys"
$result = Invoke-RestMethod -Method GET -Uri $uri -Certificate $subscription.Certificate -Headers @{'x-ms-version'='2014-08-01'} -ContentType application/xml
$ctx = New-AzureStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $result.StorageService.StorageServiceKeys.Primary

Write-Host "Uploading extension package $packagePath to azure storage account $storageAccountName container $storageContainerName blob $storageBlobName"
#Set-AzureStorageBlobContent -Container $storageContainerName -File $packagePath -Blob $storageBlobName -Context $ctx -Force


$method = "PUT"
$headerDate = '2017-04-17'
$headers = @{"x-ms-version"="$headerDate"}
$StorageAccountKey = $result.StorageService.StorageServiceKeys.Primary
$Url = "https://${storageAccountName}.blob.core.windows.net/${storageContainerName}/${storageBlobName}"
$xmsdate = (get-date -format r).ToString()
$content = [System.IO.File]::ReadAllBytes("$packagePath")
$item = Get-Item "$packagePath"
$length = $item.Length
$headers.Add("x-ms-date",$xmsdate)
$headers.Add("x-ms-blob-type","BlockBlob")
$headers.Add("Content-Type", "application/zip, application/octet-stream")
$headers.Add("Content-Length","$length")
$signatureString = "${method}$([char]10)$([char]10)$([char]10)$length$([char]10)$([char]10)application/zip, application/octet-stream$([char]10)$([char]10)$([char]10)$([char]10)$([char]10)$([char]10)$([char]10)x-ms-blob-type:BlockBlob$([char]10)"
#Add CanonicalizedHeaders
$signatureString += "x-ms-date:" + $headers["x-ms-date"] + "$([char]10)"
$signatureString += "x-ms-version:" + $headers["x-ms-version"] + "$([char]10)"
$signatureString += "/${storageAccountName}/${storageContainerName}/${storageBlobName}"
#Add CanonicalizedResource
$uri = New-Object System.Uri -ArgumentList $Url
$dataToMac = [System.Text.Encoding]::UTF8.GetBytes($signatureString)
$accountKeyBytes = [System.Convert]::FromBase64String($StorageAccountKey)
$hmac = new-object System.Security.Cryptography.HMACSHA256((,$accountKeyBytes))
$signature = [System.Convert]::ToBase64String($hmac.ComputeHash($dataToMac))
$headers.Add("Authorization", "SharedKey " + $storageAccountName + ":" + $signature);
write-host -fore green $signatureString
$str = $headers | Out-String
write-host -fore green $str 
Invoke-RestMethod -Uri $Url -Method $method -headers $headers -Body $content













## Commenting this out as Azure PIR replication does not support SAS tokens
#$startTime = Get-Date
#$endTime = $startTime.AddDays(7)
#$sasToken = New-AzureStorageBlobSASToken -Container $storageContainerName -Blob $storageBlobName -Permission r -ExpiryTime $endTime -Context $ctx -FullUri

#$sasToken
#[xml]$definitionXml = [xml](Get-Content $definitionFile)
#$definitionXml.ExtensionImage.MediaLink = [string]$sasToken
#$($definitionXml.ExtensionImage.MediaLink)

#$definitionXml.Save((Resolve-Path $definitionFile))
