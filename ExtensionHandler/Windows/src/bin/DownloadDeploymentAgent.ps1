#To pass the log method to this script - 
#
# DeploymentAgent.ps1 -tfsUrl "https://myvstsaccout.visualstusio.com" -patToken ........


param(
    [Parameter(Mandatory=$true)]
    [string]$tfsUrl,
    [Parameter(Mandatory=$false)]
    [string]$patToken,
    [Parameter(Mandatory=$true)]
    [string]$workingFolder
)

$ErrorActionPreference = 'Stop'
Import-Module $PSScriptRoot\Log.psm1
. "$PSScriptRoot\Constants.ps1"

function WriteDownloadLog
{
    param(
    [string]$logMessage
    )
    
    Write-Log ("[Download]: " + $logMessage)
}
 
 function GetAgentPackageData
 {
    Param(
    [Parameter(Mandatory=$true)]
    [string]$restCallUrl,
    [Parameter(Mandatory=$false)]
    [string]$patToken
    )
    
    WriteDownloadLog "`t`t Invoke-rest call for packageData"
    $headers = Get-RESTCallHeader $config.PATToken
    $getAgentPackageDataErrorMessageBlock = {
        $exception = $_
        $message = "An error occured while downloading VSTS agent. {0}"
        if($exception.Exception.Response)
        {
            $message -f "Status: $($exception.Exception.Response.StatusCode.value__)"
        }
        else
        {
            $message -f "$($exception.Exception)"
        }
    }
    $response = Invoke-WithRetry -retryBlock {Invoke-RestMethod -Uri $restCallUrl -Method "Get" -Headers $headers} `
                               -retryCatchBlock {WriteDownloadLog (& $getAgentPackageDataErrorMessageBlock)} -finalCatchBlock {throw (& $getAgentPackageDataErrorMessageBlock)}

    WriteDownloadLog "`t`t Agent PackageData : $response"
    return $response.Value[0]
}
 
 function GetAgentDownloadUrl
 {
    Param(
    [Parameter(Mandatory=$true)]
    [string]$tfsUrl,
    [Parameter(Mandatory=$false)]
    [string]$patToken    
    )

    $restCallUrl = $tfsUrl + ("/_apis/distributedtask/packages/agent/{0}?top=1&api-version={1}" -f $platform,$downloadAPIVersion)
       
    WriteDownloadLog "`t`t Get Agent PackageData using $restCallUrl"  
    $packageData = GetAgentPackageData -restCallUrl $restCallUrl -patToken $patToken

    WriteDownloadLog "Deployment Agent download url - $($packageData.downloadUrl)"
    
    return $packageData.downloadUrl
   
 }

 function DowloadDeploymentAgent
 {
    Param(
    [Parameter(Mandatory=$true)]
    [string]$agentDownloadUrl,
    [Parameter(Mandatory=$true)]
    [string]$target
    )

    if( Test-Path $target )
    {
        WriteDownloadLog "`t`t $target already exists, deleting it."
        Remove-Item $target -Force
    }
    
    WriteDownloadLog "`t`t Start DeploymentAgent download"
    Invoke-WithRetry -retryBlock {(New-Object Net.WebClient).DownloadFile($agentDownloadUrl,$target)} `
                     -retryCatchBlock {WriteDownloadLog $_} -finalCatchBlock {throw $_}
    WriteDownloadLog "`t`t DeploymentAgent download done"
 }

 function ExtractZip
 {
    Param(
    [Parameter(Mandatory=$true)]
    [string]$sourceZipFile,
    [Parameter(Mandatory=$true)]
    [string]$target
    )
    
    try
    {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($sourceZipFile, $target)
    }
    catch
    {
        $fileInfo = Get-Item -Path $sourceZipFile
        $appName = New-Object -ComObject Shell.Application
        $zipName = $appName.NameSpace($fileInfo.FullName)
        $dstFolder = $appName.NameSpace($target)
        $dstFolder.Copyhere($zipName.Items(), 1044)
    }   
 }
 
function DownloadAgentZipRequired
{
    $retVal = $true
    WriteDownloadLog "Read the variable: $agentDownloadRequiredVarName"
    try
    {
        $retVal = Get-Variable -Scope "Global" -Name $agentDownloadRequiredVarName -ValueOnly
    }
    catch
    {
        Write-Verbose -Verbose $_.Exception
        
        WriteDownloadLog "Unable to get variable: $agentDownloadRequiredVarName"
    } 
    
    return $retVal
}

try
{
    WriteDownloadLog "Starting the DowloadDeploymentAgent script"
     
    WriteDownloadLog "Get the url for downloading the agent"
    $agentDownloadUrl = GetAgentDownloadUrl -tfsUrl $tfsUrl -patToken $patToken

    WriteDownloadLog "Get the target zip file path"
    $agentZipFilePath = Join-Path $workingFolder $agentZipName
    WriteDownloadLog "`t`t Deployment agent will be downloaded at - $agentZipFilePath"

    WriteDownloadLog "Downloading deploymentAgent"
    DowloadDeploymentAgent -agentDownloadUrl $agentDownloadUrl -target $agentZipFilePath
    WriteDownloadLog "Done with DowloadDeploymentAgent script"
    
    return $returnSuccess
}
catch
{  
    WriteDownloadLog $_.Exception
    throw $_.Exception
}
