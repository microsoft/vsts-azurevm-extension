<#
.Synopsis
    Waits for Azure PIR to complete replication of VM extension

.Usage
    WaitForExtensionReplication.ps1 -extensionName ReleaseManagement1 -publisher Test.Microsoft.VisualStudio.Services -extensionVersion 1.9.0.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$extensionName,

    [Parameter(Mandatory=$true)]
    [string]$publisher,

    [Parameter(Mandatory=$true)]
    [string]$extensionVersion,

    [Parameter(Mandatory=$true)]
    [string]$location
)

if($extensionVersion -eq "WILL_BET_SET_AT_RUNTIME")
{
    return
}

$retryCount = 0
$isReplicated = $false

# retry after every 120 seconds
$retryInterval = 120

# maximum number of retries to attempt
$maxRetries = 720

do
{
  Start-Sleep -s $retryInterval

  try 
  {
      $extensionDetails = Get-AzureRmVMExtensionImage -Location $location -PublisherName $publisher -Type $extensionName -Version $extensionVersion
      $isReplicated = $extensionDetails.Version -eq $extensionVersion
  }
  catch 
  {
      $isReplicated = $false
  }
  
  if($isReplicated -ne $true)
  {
    Write-Host "Extension is not yet replicated. Will retry after $retryInterval seconds"
    $retryCount++
  }

} While (($isReplicated -ne $true) -and ($retryCount -lt $maxRetries))