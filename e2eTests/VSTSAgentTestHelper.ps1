function Get-VSTSAgentInformation
{
    param(
    [string]$vstsUrl,
    [string]$teamProject,
    [string]$patToken,
    [string]$deploymentGroup,
    [string]$agentName
    )
    
    Write-Host "Looking for agent $agentName in vsts account $vstsUrl and deployment group $deploymentGroup"
    $base64AuthToken = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f "", $patToken)))
    $authHeader = @{ Authorization = "Basic {0}" -f $base64AuthToken }

    $uri = "{0}/{1}/_apis/distributedtask/deploymentgroups" -f $vstsUrl, $teamProject
    $deploymentGroupsResponse = Invoke-RestMethod -Method GET -Uri $uri -Headers $authHeader
    $deploymentGroups = $deploymentGroupsResponse.value
    $deploymentGroups | % {
        if($_.name -eq $deploymentGroup)
        {   
            $deploymentGroupId = $_.id
            return
        }
    }

    Write-Host "Deployment group Id: $deploymentGroupId"

    $uri = "{0}/{1}/_apis/distributedtask/deploymentgroups/{2}" -f $vstsUrl, $teamProject, $deploymentGroupId
    $agentsResponse = Invoke-RestMethod -Method GET -Uri $uri -Headers $authHeader
    $agents = $agentsResponse.machines
    $poolId = $agentsResponse.pool.id

    $agentExists = $false
    $agentOnline = $false
    $agents | % {
        if($_.agent.name -eq $agentName)
        {
            $agentExists = $true
            $agentId = $_.agent.id
            if($_.agent.status -eq "online")
            {
                $agentOnline = $true
            }
            return
        }
    }

    Write-Host "Agent $agentName exists: $agentExists"
    Write-Host "Agent $agentName online: $agentOnline"
    Write-Host "Agent Id: $agentId"

    return @{
        isAgentExists = $agentExists
        isAgentOnline = $agentOnline
        deploymentGroupId = $deploymentGroupId
        poolId = $poolId
        agentId = $agentId
    }
}

function Remove-VSTSAgent
{
    param(
    [string]$vstsUrl,
    [string]$teamProject,
    [string]$patToken,
    [string]$deploymentGroupId,
    [string]$agentId
    )

    Write-Host "Removing agent with id $agentId from vsts account $vstsUrl"
    $base64AuthToken = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f "", $patToken)))
    $authHeader = @{ Authorization = "Basic {0}" -f $base64AuthToken }
    $uri = "{0}/{1}/_apis/distributedtask/deploymentgroups/{2}/machines/{3}?api-version=4.0-preview" -f $vstsUrl, $teamProject, $deploymentGroupId, $agentId
    Write-Host "$uri"
    Invoke-RestMethod -Method DELETE -Uri $uri -Headers $authHeader
}