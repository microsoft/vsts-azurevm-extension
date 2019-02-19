<#
.Synopsis
    Detects the oldest version of published extension and sets a release variable value
    Has an optional parameter to skip deleting specific version, accepted as input in semicolon separated form. 

.Usage
    DetectOldVersionExtensionToDelete.ps1 -extensionName ReleaseManagement1 -publisher Test.Microsoft.VisualStudio.Services -versionToDelete 1.9.0.0 -versionsToSkip "1.1.0.0; 1.2.0.0"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$extensionName,
    [Parameter(Mandatory=$true)]
    [string]$publisher,
    [Parameter(Mandatory=$false)]
    [string]$versionsToSkip
)

$versionToDelete = "NOTHING_TO_DELETE"

# Fetching list of published extension handler. Using South Central US location. Since, we are insterested in oldest version, it does not matter which location we use as replication would have anyways completed.
# The returned list is already sorted by oldest published version first
$extensions = Get-AzureRmVMExtensionImage -Location southcentralus -PublisherName $publisher -Type $extensionName
if($versionsToSkip.Trim())
{
    $versionsToSkipArray = $versionsToSkip.Split(";") | %{$_.Trim()}
    Write-Host "Will skip deleting the following versions: $versionsToSkipArray"
    $extensions = $extensions | Where-Object {!$versionsToSkipArray.Contains($_.Version)}
}
$extensions =  $extensions | Sort-Object -Property @{Expression = {[int]$_.Version.Split(".")[0]}}, @{Expression = {[int]$_.Version.Split(".")[1]}}

Write-Host "Published extension handler versions:"
$extensions | % { Write-Host $_.version}

if($extensions.Count -ge 5) 
{
    $versionToDelete = $extensions[0].Version
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
