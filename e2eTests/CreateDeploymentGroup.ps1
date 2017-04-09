param(
    [Parameter(Mandatory=$true)]
    [string]$TeamProject,
    [Parameter(Mandatory=$true)]
    [string]$PATToken,
    [Parameter(Mandatory=$true)]
    [string]$DeploymentGroup
)

$uri = "http://localhost:8080/tfs/defaultcollection/{0}/_apis/distributedtask/DeploymentGroups?api-version=3.2-preview.1" -f $TeamProject

$deploymentGroupParam = @{
    name = $DeploymentGroup;
}

$body = $deploymentGroupParam | ConvertTo-Json
$body

$base64AuthToken = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f "", $PATToken)))
$headers = @{ 
    Authorization = "Basic {0}" -f $base64AuthToken;
    "Content-Type" = "application/json";
 }

Invoke-RestMethod -Method POST -Uri $uri -UseDefaultCredentials -Headers $headers -Body $body