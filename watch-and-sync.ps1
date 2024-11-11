# IMPORTANT: This script is intended to be run in a WSL environment. Hence you need to have WSL installed and the rsync package installed in your WSL environment. In addition, your SSH keys need to be set up in your WSL environment.

if ($args.Length -eq 0) {
    Write-Host "Usage: .\watch-and-sync.ps1 <user@remote_server>"
    exit 1
}

$RemoteServer = $args[0]

$LocalPath = Join-Path -Path (Get-Location).Path -ChildPath "./ExtensionHandler/Linux/src/"
$RemoteUser = $RemoteServer.Split("@")[0]
$RemotePath = "${RemoteServer}:/home/${RemoteUser}/extension-1.0"

$LocalPathWSL = wsl wslpath -a $($LocalPath -replace '\\', '\\\\')

function Invoke-Rsync {
    wsl rsync -avz --exclude=".git/"  --exclude="__pycache__" --exclude="HanderEnvironment.json" --delete --chmod=Du=rwx,Dg=rx,Do=rx,Fu=rw,Fg=r,Fo=r "$LocalPathWSL" "$RemotePath"
}

Write-Host "Starting initial sync..."
Invoke-Rsync
Write-Host "Initial sync completed."


Write-Host "Starting to monitor for changes..."
$lastRun = (Get-Date)

while ($true) {
    $latestChange = Get-ChildItem -Recurse -File $LocalPath | 
                    Sort-Object LastWriteTime -Descending | 
                    Select-Object -First 1 | 
                    ForEach-Object { $_.LastWriteTime }

    if ($latestChange -gt $lastRun) {
        Write-Host "Change detected; syncing..."
        Invoke-Rsync
        Write-Host "Sync completed."

        $lastRun = Get-Date
    }

    Start-Sleep -Seconds 5
}
