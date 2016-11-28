param(
    [Parameter(Mandatory=$true)]
    [string]$DropFetchExeLocation,
    [Parameter(Mandatory=$true)]
    [string]$ProductGroups,
    [Parameter(Mandatory=$true)]
    [string]$Configuration,
    [Parameter(Mandatory=$true)]
    [string]$msengDropService,
    [Parameter(Mandatory=$true)]
    [string]$msengProject,
    [Parameter(Mandatory=$true)]
    [string]$msengBuildNumber,
    [Parameter(Mandatory=$true)]
    [string]$msengPATToken,
    [Parameter(Mandatory=$true)]
    [string]$Destination
)

# Cleanup destination folder
if(Test-Path $Destination)
{
    Remove-Item $Destination -Recurse
}

$dropFetch = Join-Path $DropFetchExeLocation VssDropFetch.exe
& $dropFetch FetchProduct /productGroups:$ProductGroups /configuration:$Configuration  /dropService:$msengDropService /project:$msengProject /build:$msengBuildNumber /destination:"$Destination\bin" /purge /WarningsToStdOut /accessToken:$msengPATToken