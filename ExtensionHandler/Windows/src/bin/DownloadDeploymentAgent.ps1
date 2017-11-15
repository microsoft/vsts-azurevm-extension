#To pass the log method to this script - 
#
# DeploymentAgent.ps1 -tfsUrl "https://myvstsaccout.visualstusio.com" -patToken ........ -logFunction ${function:My-Logmethod}


param(
    [Parameter(Mandatory=$true)]
    [string]$tfsUrl,
    [Parameter(Mandatory=$false)]
    [string]$patToken,
    [Parameter(Mandatory=$true)]
    [string]$platform,
    [Parameter(Mandatory=$true)]
    [string]$workingFolder,
    [string]$userName,
    [scriptblock]$logFunction
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\Constants.ps1"

function WriteDownloadLog
{
    param(
    [string]$logMessage
    )
    
    $log = "[Download]: " + $logMessage
    if($logFunction -ne $null)
    {
        $logFunction.Invoke($log)
    }
    else
    {
        write-verbose $log
    }
}
 
 function ContructPackageDataRESTCallUrl
 {
    Param(
    [Parameter(Mandatory=$true)]
    [string]$tfsUrl,
    [Parameter(Mandatory=$true)]
    [string]$platform
    )

    [string]$restCallUrl = $tfsUrl + ("/_apis/distributedtask/packages/agent/{0}?top=1&api-version={1}" -f $platform,$downloadAPIVersion)
    
    WriteDownloadLog "`t`t REST call Url -  $restCallUrl"
    
    return $restCallUrl
 }
 
 function GetAgentPackageData
 {
    Param(
    [Parameter(Mandatory=$true)]
    [string]$restCallUrl,
    [Parameter(Mandatory=$true)]
    [string]$restCallUrlOld,   
    [string]$userName,
    [Parameter(Mandatory=$false)]
    [string]$patToken
    )
    
    WriteDownloadLog "`t`t Form the header for invoking the rest call"
    
    $basicAuth = ("{0}:{1}" -f $username, $patToken)
    $basicAuth = [System.Text.Encoding]::UTF8.GetBytes($basicAuth)
    $basicAuth = [System.Convert]::ToBase64String($basicAuth)
    $headers = @{Authorization=("Basic {0}" -f $basicAuth)}
    
    WriteDownloadLog "`t`t Invoke-rest call for packageData"
    try
    {
        $response = Invoke-RestMethod -Uri $($restCallUrl) -headers $headers -Method Get -ContentType "application/json"
        WriteDownloadLog "`t`t Agent PackageData : $response"
        if($response.Value.Count -gt 0){
            return $response.Value[0]
        }
        else{
            # Back compat for old package key
            $response = Invoke-RestMethod -Uri $($restCallUrlOld) -headers $headers -Method Get -ContentType "application/json"
            WriteDownloadLog "`t`t Agent PackageData : $response"
            return $response.Value[0]
        }
    }
    catch
    {
        throw "Error while downloading VSTS extension. Please make sure that you enter the correct VSTS account name and PAT token."
    }
}
 
 function GetAgentDownloadUrl
 {
    Param(
    [Parameter(Mandatory=$true)]
    [string]$tfsUrl,
    [Parameter(Mandatory=$true)]
    [string]$platform,    
    [string]$userName,
    [Parameter(Mandatory=$false)]
    [string]$patToken    
    )

    [string]$restCallUrl = ContructPackageDataRESTCallUrl -tfsUrl $tfsUrl -platform $platform
    [string]$restCallUrlOld = ContructPackageDataRESTCallUrl -tfsUrl $tfsUrl -platform $platformKeyOld
    
    WriteDownloadLog "`t`t Get Agent PackageData using $restCallUrl"  
    $packageData = GetAgentPackageData -restCallUrl $restCallUrl -restCallUrlOld $restCallUrlOld -userName $userName -patToken $patToken

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
    (New-Object Net.WebClient).DownloadFile($agentDownloadUrl,$target)
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
        $fileInfo = Get-Item -Path $sourceZipFile
        $appName = New-Object -ComObject Shell.Application
        $zipName = $appName.NameSpace($fileInfo.FullName)
        $dstFolder = $appName.NameSpace($target)
        $dstFolder.Copyhere($zipName.Items(), 1044)
    }
    catch
    {
        $sourceZipFileItem = Get-Item -Path $sourceZipFile
        Remove-Item "$target\*" -Recurse -Exclude $sourceZipFileItem.Name
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($sourceZipFile, $target)
    }

    WriteDownloadLog "`t`t $sourceZipFile is extracted to $target"    
 }

 function GetTargetZipPath
 {
    Param(
    [Parameter(Mandatory=$true)]
    [string]$workingFolder,
    [Parameter(Mandatory=$true)]
    [string]$agentZipName
    )
    
    return Join-Path $workingFolder $agentZipName

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
     
    if([string]::IsNullOrEmpty($userName))
    {
        $userName = ' '
        WriteDownloadLog "No user name provided setting as empty string"
    }
     
     WriteDownloadLog "Get the url for downloading the agent"
     
     $agentDownloadUrl = GetAgentDownloadUrl -tfsUrl $tfsUrl -platform $platform -userName $userName -patToken $patToken

     WriteDownloadLog "Get the target zip file path"
     
     $agentZipFilePath = GetTargetZipPath -workingFolder $workingFolder -agentZipName $agentZipName
     
     WriteDownloadLog "`t`t Deployment agent will be downloaded at - $agentZipFilePath"
     
     WriteDownloadLog "Download deploymentAgent"
     
     DowloadDeploymentAgent -agentDownloadUrl $agentDownloadUrl -target $agentZipFilePath
     
     WriteDownloadLog "Extract zip $agentZipFilePath to $workingFolder"
     
     ExtractZip -sourceZipFile $agentZipFilePath -target $workingFolder
     
     WriteDownloadLog "Done with DowloadDeploymentAgent script"
     
     return $returnSuccess 
 }
 catch
 {  
    WriteDownloadLog $_.Exception
    throw $_.Exception
 }
