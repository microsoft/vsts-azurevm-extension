param (
    [String]$thumbprint,
    [String]$sitename="Team Foundation Server",
    [int]$port=4443
    )

if (-not($thumbprint))
{
  Write-Error "Certificate Thumprint is needed"
  exit
}

Import-Module WebAdministration

function AddHTTPSBinding([String]$thumbprint, [String]$sitename, [int]$port)
{
    $cert = Get-ChildItem cert:\LocalMachine\root | ?{$_.Thumbprint -eq $thumbprint}
    
    if( -not($(gci iis:\sslbindings| ? {$_.Port -eq $port})))
    {
        New-Item IIS:\SslBindings\0.0.0.0!$port -Value $cert | out-null
        New-ItemProperty $(join-path iis:\Sites $sitename) -name bindings -value @{protocol="https";bindingInformation="*:$($port):";certificateStoreName="My";certificateHash=$thumbprint}
    }
    else
    {
        Write-Warning "SSL binding already exists on port $port"
    }
}

AddHTTPSBinding $thumbprint $sitename $port
