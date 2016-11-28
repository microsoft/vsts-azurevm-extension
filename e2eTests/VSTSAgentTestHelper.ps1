function Get-VSTSAgentInformation
{
    param(
    [string]$vstsUrl,
    [string]$teamProject,
    [string]$patToken,
    [string]$machineGroup,
    [string]$agentName
    )
    
    Write-Host "Looking for agent $agentName in vsts account $vstsUrl and machine group $machineGroup"
    $base64AuthToken = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f "", $patToken)))
    $authHeader = @{ Authorization = "Basic {0}" -f $base64AuthToken }

    $uri = "{0}/{1}/_apis/distributedtask/machinegroups" -f $vstsUrl, $teamProject
    $machineGroupsResponse = Invoke-RestMethod -Method GET -Uri $uri -Headers $authHeader
    $machineGroups = $machineGroupsResponse.value
    $machineGroups | % {
        if($_.name -eq $machineGroup)
        {   
            $machineGroupId = $_.id
            return
        }
    }

    Write-Host "Machine group Id: $machineGroupId"

    $uri = "{0}/{1}/_apis/distributedtask/machinegroups/{2}" -f $vstsUrl, $teamProject, $machineGroupId
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
        machineGroupId = $machineGroupId
        poolId = $poolId
        agentId = $agentId
    }
}

function Remove-VSTSAgent
{
    param(
    [string]$vstsUrl,
    [string]$patToken,
    [string]$poolId,
    [string]$agentId
    )

    Write-Host "Removing agent with id $agentId from vsts account $vstsUrl"
    $base64AuthToken = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f "", $patToken)))
    $authHeader = @{ Authorization = "Basic {0}" -f $base64AuthToken }
    $uri = "{0}/_apis/distributedtask/pools/{1}/agents/{2}?api-version=3.0" -f $vstsUrl, $poolId, $agentId
    Invoke-RestMethod -Method DELETE -Uri $uri -Headers $authHeader
}