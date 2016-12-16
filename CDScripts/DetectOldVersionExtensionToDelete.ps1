<#
.Synopsis
    Delete older version of extension from PIR. this is required as Azure only suuports 15 extension versions from a partiular subscription.

.Usage
    DeleteOldExtension.ps1 -extensionName ReleaseManagement1 -publisher Test.Microsoft.VisualStudio.Services -versionToDelete 1.9.0.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$extensionName,

    [Parameter(Mandatory=$true)]
    [string]$publisher,
    
    [string]$versionToDelete
)


# Fetching list of published extension handler. Using South Central US location. Since, we are insterested in oldest version, it does not matter which location we use as replication would have anyways completed.
# The returned list is already sorted by oldest published version first
$extensions = Get-AzureRmVMExtensionImage -Location southcentralus -PublisherName $publisher -Type $extensionName

Write-Host "Published extension handler versions:"
$extensions | % { Write-Host $_.version}

if($extensions.Count -ge 5) 
{
    $versionToDelete = $extensions[1].Version
    Write-Host "5 or more extension handler versions are published. Oldest version can be deleted"
}
else
{
    $versionToDelete = "NOTHING_TO_DELETE"
    Write-Host "Less than 5 handler version published currently. None can be deleted"
}

# set this version as value for release variable 
$oldVersionVariable = "OldVersionToBeDeleted"
Write-Host "##vso[task.setvariable variable=$oldVersionVariable;]$versionToDelete"
exit 0