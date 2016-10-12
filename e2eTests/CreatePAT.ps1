$uri = "http://localhost:8080/tfs/_apis/token/sessiontokens?api-version=1.0&tokentype=compact"

$tokenParams = @{
    scope = "vso.agentpools_manage";
    targetAccounts = @("null");
    displayName = "VMExtensionE2ETest";
}

$headers = @{ 
    "Content-Type" = "application/json";
}

$body = $tokenParams | ConvertTo-Json
$body

$response = Invoke-RestMethod -Method POST -Uri $uri -UseDefaultCredentials -Headers $headers -Body $body

Write-Host "PAT token: "  $response.token