<#
.Synopsis
    Waits for Azure PIR to complete replication of VM extension
#>

$retryCount = 0
$isReplicated = $false

# retry after every 30 seconds
$retryInterval = 30

# maximum number of retries to attempt
$maxRetries = 2 * 30

do
{
  Start-Sleep -s 30
  
  $extension = Get-AzureVMAvailableExtension -ExtensionName ReleaseManagement1 -Publisher Test.Microsoft.VisualStudio.Services
  $isReplicated = $extension.ReplicationCompleted
  
  if($isReplicated -ne $true)
  {
    Write-Host "Extension is not yet replicated. Will retry after 30 seconds"
    $retryCount++
  }

} While (($isReplicated -ne $true) -and ($retryCount -lt 60))