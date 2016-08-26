param(
    [Parameter(Mandatory=$true)]
    [string]$tfsUrl,
    [Parameter(Mandatory=$true)]
    [string]$patToken,
    [Parameter(Mandatory=$true)]
    [string]$platform,
    [Parameter(Mandatory=$true)]
    [string]$workingFolder,
    [string]$userName
    )

$ErrorActionPreference = 'Stop'
 
$downloadAPIVersion = "3.0-preview.2"
$deploymentAgentFolderName = "DeploymentAgent"
$loggingDiagFolderName = "_diag"   
$agentZipName = "agent.zip"
$minPSVersionSupported = 3

$debug = $true

 function InitLogging
 {  
    $diagFolder = Join-Path $workingFolder $loggingDiagFolderName
    
    if( !(Test-Path $diagFolder -pathType container) )
    {
        New-Item $diagFolder -Type directory | Out-Null
    }
    
    $logFileName = $deploymentAgentFolderName + '-' + ((get-date).ToUniversalTime()).ToString("yyyyMMdd-HHmmss") + '-utc.txt' 
    
    $logFile = Join-Path $diagFolder $logFileName
    
    New-Item $logFile -Type file -force | Out-Null  

    return $logFile
 }

 function WriteLog
 {
    param(
    [string]$logMessage
    )
    
    if($debug)
    {
        write-verbose $logMessage -verbose
    }
    if( Test-Path $logFile )
    {
        Write-Output $logMessage | Out-File $logFile -Append
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
    
    WriteLog "`t`t Reset call Url -  $restCallUrl"
    
    return $restCallUrl
 }
 
 function GetAgentPackageData
 {
    Param(
    [Parameter(Mandatory=$true)]
    [string]$restCallUrl,   
    [string]$userName,
    [Parameter(Mandatory=$true)]
    [string]$patToken
    )
    
    WriteLog "`t`t Form the header for invoking the rest call"
    
    $basicAuth = ("{0}:{1}" -f $username, $patToken)
    $basicAuth = [System.Text.Encoding]::UTF8.GetBytes($basicAuth)
    $basicAuth = [System.Convert]::ToBase64String($basicAuth)
    $headers = @{Authorization=("Basic {0}" -f $basicAuth)}
    
    WriteLog "`t`t Invoke-rest call for packageData"
    $response = Invoke-RestMethod -Uri $($restCallUrl) -headers $headers -Method Get -ContentType "application/json"
    WriteLog "`t`t Agent PackageData : $response"

    return $response.Value[0]
 }
 
 function GetAgentDownloadUrl
 {
    Param(
    [Parameter(Mandatory=$true)]
    [string]$tfsUrl,
    [Parameter(Mandatory=$true)]
    [string]$platform,    
    [string]$userName,
    [Parameter(Mandatory=$true)]
    [string]$patToken    
    )

    [string]$restCallUrl = ContructPackageDataRESTCallUrl -tfsUrl $tfsUrl -platform $platform
    
    WriteLog "`t`t Get Agent PackageData using $restCallUrl"  
    $packageData = GetAgentPackageData -restCallUrl $restCallUrl -userName $userName -patToken $patToken

    WriteLog "Deployment Agent download url - $($packageData.downloadUrl)"
    
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
        WriteLog "`t`t $target already exists, deleting it."
        Remove-Item $target -Force
    }
    
    WriteLog "`t`t Start DeploymentAgent download"
    (New-Object Net.WebClient).DownloadFile($agentDownloadUrl,$target)
    WriteLog "`t`t DeploymentAgent download done"
 }
 
 function ExtractZip
 {
    Param(
    [Parameter(Mandatory=$true)]
    [string]$sourceZipFile,
    [Parameter(Mandatory=$true)]
    [string]$target
    )
    
    $fileInfo = Get-Item -Path $sourceZipFile
	$appName = New-Object -ComObject Shell.Application
	$zipName = $appName.NameSpace($fileInfo.FullName)
	$dstFolder = $appName.NameSpace($target)

    $dstFolder.Copyhere($zipName.Items(), 1044)

    WriteLog "`t`t $sourceZipFile is extracted to $target"    
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
 
 try
 {
     $logFile = InitLogging 
     
     WriteLog "Starting the DowloadDeploymentAgent script"
     
     $psVersion = $PSVersionTable.PSVersion.Major
     if( !( $psVersion -ge $minPSVersionSupported ) )
     {
        throw "Installed PowerShell version is $psVersion. Minimum required version is $minPSVersionSupported."
     }
     
     if([string]::IsNullOrEmpty($userName))
     {
        $userName = ' '
        WriteLog " No user name provided setting as empty string"
     }
     
     WriteLog "Get the url for downloading the agent"
     
     $agentDownloadUrl = GetAgentDownloadUrl -tfsUrl $tfsUrl -platform $platform -userName $userName -patToken $patToken

     WriteLog "Get the target zip file path"
     
     $agentZipFilePath = GetTargetZipPath -workingFolder $workingFolder -agentZipName $agentZipName
     
     WriteLog "`t`t Deployment agent will be downloaded at - $agentZipFilePath"
     
     WriteLog "Download deploymentAgent"
     
     DowloadDeploymentAgent -agentDownloadUrl $agentDownloadUrl -target $agentZipFilePath
     
     WriteLog "Extract zip $agentZipFilePath to $workingFolder"
     
     ExtractZip -sourceZipFile $agentZipFilePath -target $workingFolder
     
     WriteLog "Done with DowloadDeploymentAgent script"
 }
 catch
 {  
    WriteLog $_.Exception
    throw $_.Exception
 }