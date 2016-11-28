param( 
    [string]$TeamProject,
    [Parameter(Mandatory=$true)]
    [string]$PATToken,
    [Parameter(Mandatory=$true)]
    [string]$MachineGroup,
    [Parameter(Mandatory=$true)]
    [string]$AgentName
    )

. "$PSScriptRoot\VSTSAgentTestHelper.ps1"

$VSTSUrl = "http://localhost:8080/tfs/defaultcollection"

# Remove any old agent which is till registered
$oldAgentInfo = Get-VSTSAgentInformation -vstsUrl $VSTSUrl -teamProject $TeamProject -patToken $PATToken -machineGroup $MachineGroup -agentName $AgentName
if($oldAgentInfo.isAgentExists -eq $true)
{
    Remove-VSTSAgent -vstsUrl $VSTSUrl -patToken $PATToken -poolId $oldAgentInfo.poolId -agentId $oldAgentInfo.agentId
}