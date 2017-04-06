param(
    [Parameter(Mandatory=$true)]
    [string]$TeamProject,
    [Parameter(Mandatory=$true)]
    [string]$PATToken,
    [Parameter(Mandatory=$true)]
    [string]$DeploymentGroup,
    [Parameter(Mandatory=$true)]
    [string]$WindowsAgentName,
    [Parameter(Mandatory=$true)]
    [string]$LinuxAgentName
)

function Confirm-AgentRegistered
{
    param(
        [Parameter(Mandatory=$true)]
        [string]$TeamProject,
        [Parameter(Mandatory=$true)]
        [string]$PATToken,
        [Parameter(Mandatory=$true)]
        [string]$DeploymentGroup,
        [Parameter(Mandatory=$true)]
        [string]$AgentName
    )

    # Verify that agent is correctly configured against VSTS
    Write-Verbose -Verbose "Validating that agent $AgentName has been registered..."
    Write-Verbose -Verbose "Getting agent information from VSTS"

    $agentInfo = Get-VSTSAgentInformation -vstsUrl "http://localhost:8080/tfs/defaultcollection" -teamProject $TeamProject -patToken $PATToken -deploymentGroup $DeploymentGroup -agentName $AgentName

    if(($agentInfo.isAgentExists -eq $false) -or ($agentInfo.isAgentOnline -eq $false))
    {
        Write-Error "Agent $AgentName has not been registered with VSTS!!"
    }
    else
    {
        Write-Verbose -Verbose "Agent $AgentName has been successfully registered with VSTS!!"
    }
}

. "$PSScriptRoot\VSTSAgentTestHelper.ps1"

$AgentNames = @($WindowsAgentName, $LinuxAgentName)
$AgentNames | % {
    Confirm-AgentRegistered -TeamProject $TeamProject -PATToken $PATToken -DeploymentGroup $DeploymentGroup -AgentName $_
}