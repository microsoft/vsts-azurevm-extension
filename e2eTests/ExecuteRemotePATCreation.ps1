param(
    [Parameter(Mandatory=$true)]
    [string]$TfatVmIP,
    [Parameter(Mandatory=$true)]
    [string]$TfatVmWinRMPort,
    [Parameter(Mandatory=$true)]
    [string]$VMUsername,
    [Parameter(Mandatory=$true)]
    [string]$VMPassword,
    [Parameter(Mandatory=$true)]
    [string]$TfatVMScriptsLocation,
    [Parameter(Mandatory=$true)]
    [string]$CreatePATScriptFileName
)

$scriptLocation = Join-Path $TfatVMScriptsLocation $CreatePATScriptFileName
Write-Host $scriptLocation
$password = ConvertTo-SecureString $VMPassword -AsPlainText -Force
$cred= New-Object System.Management.Automation.PSCredential ($VMUsername, $password)
$session = New-PSSession -ComputerName $TfatVmIP -Port $TfatVmWinRMPort -UseSSL -Credential $cred -SessionOption (New-PSSessionOption -SkipCACheck)
Invoke-Command -Session $session -Scriptblock { param($scriptToRun) & $scriptToRun } -ArgumentList $scriptLocation
Remove-PSSession $session