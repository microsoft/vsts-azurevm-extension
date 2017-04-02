param(
    [Parameter(Mandatory=$true)]
    [string]$TeamProject,
    [Parameter(Mandatory=$true)]
    [string]$PATToken,
    [Parameter(Mandatory=$true)]
    [string]$MachineGroup
)

$uri = "http://localhost:8080/tfs/defaultcollection/{0}/_apis/distributedtask/MachineGroups?api-version=3.1-preview.1" -f $TeamProject

$machineGroupParam = @{
    name = $MachineGroup;
}

$body = $machineGroupParam | ConvertTo-Json
$body

$base64AuthToken = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f "", $PATToken)))
$headers = @{ 
    Authorization = "Basic {0}" -f $base64AuthToken;
    "Content-Type" = "application/json";
 }

 $enableMachineGroupFeatureFlagSqlQuery = "Use Tfs_Configuration;

declare @features dbo.typ_KeyValuePairStringTableNullable
insert into @features values('#\FeatureAvailability\Entries\WebAccess.ReleaseManagement.MachineGroup\AvailabilityState\', '1')
exec prc_UpdateRegistry @partitionId=1, @identityName = '00000000-0000-0000-0000-000000000000', @registryUpdates = @features"

sqlcmd -S . -Q $enableMachineGroupFeatureFlagSqlQuery

Invoke-RestMethod -Method POST -Uri $uri -UseDefaultCredentials -Headers $headers -Body $body