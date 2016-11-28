$uri = "http://localhost:8080/tfs/_apis/token/sessiontokens?api-version=1.0&tokentype=compact"

$tokenParams = @{
    scope = "app_token";
    targetAccounts = @("null");
    displayName = "VMExtensionE2ETest";
}

$headers = @{ 
    "Content-Type" = "application/json";
}

$body = $tokenParams | ConvertTo-Json
$body

$response = Invoke-RestMethod -Method POST -Uri $uri -UseDefaultCredentials -Headers $headers -Body $body
$pat = $response.token

Write-Verbose -Verbose "PAT token: $pat"

$TfatPATVar = "PATToken"
Write-Verbose -Verbose "##vso[task.setvariable variable=$TfatPATVar;]$pat"