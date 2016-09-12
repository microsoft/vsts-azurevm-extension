<#
.Synopsis
    Waits for Azure PIR to complete replication of VM extension

.Usage
    WaitForExtensionReplicationUsingAzurePSCmdlet.ps1 -extensionName ReleaseManagement1 -publisher Test.Microsoft.VisualStudio.Services
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$extensionName,

    [Parameter(Mandatory=$true)]
    [string]$publisher
)

$retryCount = 0
$isReplicated = $false

# retry after every 60 seconds
$retryInterval = 120

# maximum number of retries to attempt
$maxRetries = 30

do
{
  Start-Sleep -s $retryInterval
  
  $extension = Get-AzureVMAvailableExtension -ExtensionName $extensionName -Publisher $publisher
  $isReplicated = $extension.ReplicationCompleted
  
  if($isReplicated -ne $true)
  {
    Write-Host "Extension is not yet replicated. Will retry after $retryInterval seconds"
    $retryCount++
  }

} While (($isReplicated -ne $true) -and ($retryCount -lt $maxRetries))