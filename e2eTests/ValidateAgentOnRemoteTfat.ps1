param(
    [Parameter(Mandatory=$true)]
    [string]$TeamProject,
    [Parameter(Mandatory=$true)]
    [string]$PATToken,
    [Parameter(Mandatory=$true)]
    [string]$MachineGroup,
    [Parameter(Mandatory=$true)]
    [string]$AgentName
)

. "$PSScriptRoot\VSTSAgentTestHelper.ps1"

# Verify that agent is correctly configured against VSTS
Write-Host "Validating that agent has been registered..."
Write-Host "Getting agent information from VSTS"
$agentInfo = Get-VSTSAgentInformation -vstsUrl "http://localhost:8080/tfs/defaultcollection" -teamProject $TeamProject -patToken $PATToken -machineGroup $MachineGroup -agentName $AgentName

if(($agentInfo.isAgentExists -eq $false) -or ($agentInfo.isAgentOnline -eq $false))
{
    Write-Error "Agent has not been registered with VSTS!!"
}
else
{
    Write-Host "Agent has been successfully registered with VSTS!!"

    #TODO: Remove agent from VSTS
}