function Check-ExtensionExistsInAzurePIR{
    param([string][Parameter(Mandatory = $true)]$subscriptionId,
        [System.Security.Cryptography.X509Certificates.X509Certificate2][Parameter(Mandatory = $true)]$certificate,
        [string][Parameter(Mandatory = $true)]$publisher,
        [string][Parameter(Mandatory = $true)]$type)

    $uri = "https://management.core.windows.net/$subscriptionId/services/publisherextensions"
    Write-Host "uri: $uri"

    # invoke GET rest api to check whether the extension already exists
    $publisherExtensions = Invoke-RestMethod -Method GET -Uri $uri -Certificate $certificate -Headers @{'x-ms-version' = '2014-08-01'}
    $checkExtension = $publisherExtensions.ExtensionImages.ExtensionImage | Where-Object {($_.ProviderNameSpace -eq $publisher) -and ($_.Type -eq $type)}
    return ($checkExtension -ne $null)
}

function Create-ExtensionPackageInAzurePIR {
    param([xml][Parameter(Mandatory = $true)]$bodyxml,
        [System.Security.Cryptography.X509Certificates.X509Certificate2][Parameter(Mandatory = $true)]$certificate,
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

function Update-ExtensionPackageInAzurePIR {
    param([xml][Parameter(Mandatory = $true)]$bodyxml,
        [System.Security.Cryptography.X509Certificates.X509Certificate2][Parameter(Mandatory = $true)]$certificate,
        [string][Parameter(Mandatory = $true)]$subscriptionId)

    $certificate.Thumbprint
    Write-Host "Updating extension to version: $($bodyxml.ExtensionImage.Version)"

    $uri = "https://management.core.windows.net/$subscriptionId/services/extensions?action=update"
    Write-Host "uri: $uri"

    # invoke PUT rest api to update the extension
    #Invoke-RestMethod -Method PUT -Uri $uri -Certificate $subscription.Certificate -Headers @{'x-ms-version'='2014-08-01'} -Body $bodyxml -ContentType application/xml

    Invoke-WithRetry -retryCommand {Invoke-RestMethod -Method PUT -Uri $uri -Certificate $certificate -Headers @{'x-ms-version' = '2014-08-01'} -Body $bodyxml.OuterXml -ContentType application/xml -ErrorAction SilentlyContinue}
           
    # set this version as value for release variable 
    $newVersion = $bodyxml.ExtensionImage.Version
    $newVersionVariable = "NewVersion"
    Write-Host "##vso[task.setvariable variable=$newVersionVariable;]$newVersion"
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
