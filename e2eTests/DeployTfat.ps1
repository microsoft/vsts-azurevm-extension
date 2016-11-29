param(
    [Parameter(Mandatory=$true)]
    [string]$BinariesDir ,
    [Parameter(Mandatory=$true)]
    [string]$Configuration,
    [Parameter(Mandatory=$true)]
    [String]$teamProject,
    [Parameter(Mandatory=$true)]
    [String]$sslThumbprint,
    [String]$sitename="Team Foundation Server",
    [int]$port=4443
)

Import-Module WebAdministration

function AddHTTPSBinding([String]$sslThumbprint, [String]$sitename, [int]$port)
{
    $cert = Get-ChildItem cert:\LocalMachine\root | ?{$_.Thumbprint -eq $sslThumbprint}
    
    if( -not($(gci iis:\sslbindings| ? {$_.Port -eq $port})))
    {
        New-Item IIS:\SslBindings\0.0.0.0!$port -Value $cert | out-null
        New-ItemProperty $(join-path iis:\Sites $sitename) -name bindings -value @{protocol="https";bindingInformation="*:$($port):";certificateStoreName="My";certificateHash=$sslThumbprint}
    }
    else
    {
        Write-Warning "SSL binding already exists on port $port"
    }
}

function Add-TeamProject
{
    param (
    [Parameter(Mandatory=$true)]
    [String]$teamProject
    )

    $uri = "http://localhost:8080/tfs/defaultcollection/_apis/projects?api-version=3.0-preview.2"

    $projectParams = @{
        name = $teamProject;
        description = "Test project for VM extension";
        capabilities = @{
            versioncontrol = @{
            sourceControlType = "Git"
            };
            processTemplate = @{
                templateTypeId = "adcc42ab-9882-485e-a3ed-7678f01f66bc"
            }
        };
    }

    $body = $projectParams | ConvertTo-Json
    $body

    $headers = @{ 
        "Content-Type" = "application/json";
    }

    $response = Invoke-RestMethod -Method POST -Uri $uri -UseDefaultCredentials -Headers $headers -Body $body
    $jobId = $response.id 

    Write-Host "Job Id: "  $jobId

    $uri = "http://localhost:8080/tfs/defaultcollection/_apis/operations/{0}" -f $jobId
    $retryCount = 0
    $isProjectCreated = $false

    # retry after every 10 seconds
    $retryInterval = 10

    # maximum number of retries to attempt
    $maxRetries = 30

    do
    { 
    # invoke GET rest api to get status of project creation
    $response = Invoke-RestMethod -Method GET -Uri $uri -UseDefaultCredentials
    $isProjectCreated = @{$true=1;$false=2}[$response.status -eq "succeeded"]
    $isProjectCreated
    
    if($isProjectCreated -ne $true)
    {
        Write-Host "Project not yet created. Will retry after $retryInterval seconds"
        $retryCount++
        Start-Sleep -s $retryInterval
    }
    else {
        Write-Host "Project created successfully"
    }

    } While (($isProjectCreated -ne $true) -and ($retryCount -lt $maxRetries))
}

# clean-up existing tfat
Write-Verbose -Verbose "Cleaning up existing tfat..."
$cleanupScript = Join-Path $BinariesDir "scripts\CDPScripts\TfsOnpremCleanup.ps1"
& $cleanupScript -BinariesDir $BinariesDir -Configuration $Configuration

# Run tfat.cmd
Write-Verbose -Verbose "Running tfat.cmd..."
$tfatScriptDir = Join-Path $BinariesDir "scripts"
$tfatScript = "$tfatScriptDir\tfat.cmd"

Set-Location $tfatScriptDir
& $tfatScript /$Configuration

# Create team project
Write-Verbose -Verbose "Creating team project..."
Add-TeamProject -teamProject $teamProject


#Start-Sleep -Seconds 60

# Add https binding
#AddHTTPSBinding $thumbprint $sitename $port