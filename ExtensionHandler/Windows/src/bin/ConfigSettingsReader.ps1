Import-Module $PSScriptRoot\AzureExtensionHandler.psm1
Import-Module $PSScriptRoot\RMExtensionStatus.psm1
Import-Module $PSScriptRoot\RMExtensionCommon.psm1 -DisableNameChecking
Import-Module $PSScriptRoot\Log.psm1
. "$PSScriptRoot\RMExtensionUtilities.ps1"

<#
.Synopsis
   Reads .settings file
   Generates configuration settings required for downloading and configuring agent
#>
function Get-ConfigurationFromSettings {
    [CmdletBinding()]
    param()

    try
    {
        . $PSScriptRoot\Constants.ps1
        Write-Log "Reading config settings from file..."

        #Retrieve settings from file
        $settings = Get-HandlerSettings
        Write-Log "Read config settings from file. Now extracting inputs and doing basic validations."

        $publicSettings = $settings['publicSettings']
        $protectedSettings = $settings['protectedSettings']
        if (-not $publicSettings)
        {
            $publicSettings = @{}
        }
        if (-not $protectedSettings)
        {
            $protectedSettings = @{}
        }

        #Extract protected settings
        $patToken = ""
        if($protectedSettings.Contains('PATToken'))
        {
            $patToken = $protectedSettings['PATToken']
        }
        if(-not $patToken -and $publicSettings.Contains('PATToken'))
        {
            $patToken = $publicSettings['PATToken']
        }

        $windowsLogonPassword = ""
        if($protectedSettings.Contains('Password'))
        {
            $windowsLogonPassword = $protectedSettings['Password']
        }
        
        #Extract and verify public settings
        $vstsAccountUrl = ""
        if($publicSettings.Contains('AzureDevOpsOrganizationUrl'))
        {
            $vstsAccountUrl = $publicSettings['AzureDevOpsOrganizationUrl']
        }
        elseif($publicSettings.Contains('VSTSAccountUrl'))
        {
            $vstsAccountUrl = $publicSettings['VSTSAccountUrl']
        }
        elseif($publicSettings.Contains('VSTSAccountName'))
        {
            $vstsAccountUrl = $publicSettings['VSTSAccountName']
        }
        Verify-InputNotNull "AzureDevOpsOrganizationUrl" $vstsAccountUrl
        $vstsUrl = $vstsAccountUrl.ToLower()
        $vstsUrl = Parse-VSTSUrl -vstsAccountUrl $vstsAccountUrl -patToken $patToken
        Write-Log "Azure DevOps Organization Url: $vstsUrl"

        $teamProjectName = $publicSettings['TeamProject']
        Verify-InputNotNull "TeamProject" $teamProjectName
        Write-Log "Team Project: $teamProjectName"

        $deploymentGroupName = $publicSettings['DeploymentGroup']
        if(-not $deploymentGroupName)
        {
            $deploymentGroupName = $publicSettings['MachineGroup']
        }
        Verify-InputNotNull "DeploymentGroup" $deploymentGroupName
        Write-Log "Deployment Group: $deploymentGroupName"

        $agentName = ""
        if($publicSettings.Contains('AgentName'))
        {
            $agentName = $publicSettings['AgentName']
        }
        Write-Log "Agent name: $agentName"

        $tagsInput = @()
        if($publicSettings.Contains('Tags'))
        {
            $tagsInput = $publicSettings['Tags']
        }
        $tagsString = $tagsInput | Out-String
        Write-Log "Tags: $tagsString"
        $tags = Format-TagsInput $tagsInput

        $windowsLogonAccountName = ""
        if($publicSettings.Contains('UserName'))
        {
            $windowsLogonAccountName = $publicSettings['UserName']
        }
        if($windowsLogonAccountName)
        {
            if(-not($windowsLogonAccountName.Contains('@') -or $windowsLogonAccountName.Contains('\')))
            {
                $windowsLogonAccountName = $env:COMPUTERNAME + '\' + $windowsLogonAccountName
            }
        }

        Write-Log "Done reading config settings from file..."
        Add-HandlerSubStatus $RM_Extension_Status.SuccessfullyReadSettings.Code $RM_Extension_Status.SuccessfullyReadSettings.Message -operationName $RM_Extension_Status.SuccessfullyReadSettings.operationName

        return @{
            VSTSUrl  = $vstsUrl
            PATToken = $patToken
            TeamProject        = $teamProjectName
            DeploymentGroup    = $deploymentGroupName
            AgentName          = $agentName
            Tags               = $tags
            WindowsLogonAccountName = $windowsLogonAccountName
            WindowsLogonPassword = $windowsLogonPassword
        }
    }
    catch
    {   
        Set-ErrorStatusAndErrorExit $_ $RM_Extension_Status.ReadingSettings.operationName
    }
}

function Confirm-InputsAreValid {
    [CmdletBinding()]
    param(
    [Parameter(Mandatory=$true, Position=0)]
    [hashtable] $config
    )

    try
    {
        $invaidPATErrorMessage = "Please make sure that the Personal Access Token entered is valid and has `"Deployment Groups - Read & manage`" scope"
        $inputsValidationErrorCode = $RM_Extension_Status.InputConfigurationError
        $unexpectedErrorMessage = "An unexpected error occured."
        $errorMessageInitialPart = ("Could not verify that the deployment group `"$($config.DeploymentGroup)`" exists in the project `"$($config.TeamProject)`" in the specified organization `"$($config.VSTSUrl)`". Status: {0}. Error: {1}")

        #Verify the deployment group exists and the PAT has the required(Deployment Groups - Read & manage) scope
        #This is the first validation http call, so using Invoke-WebRequest instead of Invoke-RestMethod, because if the PAT provided is not a token at all(not even an unauthorized one) and some random value, then the call
        #would redirect to sign in page and not throw an exception. So, to handle this case.

        $getDeploymentGroupUrl = ("{0}/{1}/_apis/distributedtask/deploymentgroups?name={2}&api-version={3}" -f $config.VSTSUrl, $config.TeamProject, $config.DeploymentGroup, $apiVersion)
        Write-Log "Get deployment group url - $getDeploymentGroupUrl"
        $headers = Get-RESTCallHeader $config.PATToken
        $getDeploymentGroupDataErrorBlock = {
            $exception = $_
            $errorMessage = "Get deployment group failed: {0}"
            $failEarly = $false
            $inputsValidationErrorCode = $RM_Extension_Status.InputConfigurationError
            if($exception.Exception.Response)
            {
                switch($exception.Exception.Response.StatusCode.value__)
                {
                    401
                    {
                        $specificErrorMessage = $invaidPATErrorMessage
                        $failEarly = $true
                    }
                    403
                    {
                        $specificErrorMessage = ("Please ensure that the user has `"View project-level information`" permissions on the project `"{0}`"" -f $config.TeamProject)
                        $failEarly = $true
                    }
                    404
                    {
                        $specificErrorMessage = "Please make sure that you enter the correct organization name and verify that the project exists in the organization"
                        $failEarly = $true
                    }
                    default
                    {
                        $specificErrorMessage = $unexpectedErrorMessage
                        $inputsValidationErrorCode = $RM_Extension_Status.GenericError
                    }
                }
                $errorMessage = ($errorMessageInitialPart -f $exception.Exception.Response.StatusCode.value__, $specificErrorMessage)
                Write-Log $errorMessage
            }
            else
            {
                $inputsValidationErrorCode = $RM_Extension_Status.MissingDependency
                $errorMessage = ($errorMessage -f $exception) + ". Please make sure that the virtual machine can access the Azure DevOps services."
                Write-Log $errorMessage $true
            }

            if($failEarly)
            {
                throw New-HandlerTerminatingError $inputsValidationErrorCode -Message $errorMessage
            }

            return $inputsValidationErrorCode, $errorMessage
        }
        $ret = Invoke-WithRetry -retryBlock {Invoke-WebRequest -Uri $getDeploymentGroupUrl -headers $headers -Method "Get" -MaximumRedirection 0 -ErrorAction Ignore -UseBasicParsing} `
                                -retryCatchBlock {$null, $null = (& $getDeploymentGroupDataErrorBlock)} -actionName "Get deploymentgroup" `
                                -finalCatchBlock {$inputsValidationErrorCode, $errorMessage = (& $getDeploymentGroupDataErrorBlock); throw New-HandlerTerminatingError $inputsValidationErrorCode -Message $errorMessage}

        $statusCode = $ret.StatusCode
        if($statusCode -eq 302)
        {
            $specificErrorMessage = $invaidPATErrorMessage
            throw New-HandlerTerminatingError $inputsValidationErrorCode -Message ($errorMessageInitialPart -f $statusCode, $specificErrorMessage)
        }
        $ret = $ret.Content | Out-String | ConvertFrom-Json
        if($ret.count -eq 0)
        {
            $specificErrorMessage = ("Please make sure that the deployment group `"{0}`" exists in the project `"{1}`", and the user has `"Manage`" permissions on the deployment group" -f $config.DeploymentGroup, $config.TeamProject)
            throw New-HandlerTerminatingError $inputsValidationErrorCode -Message ($errorMessageInitialPart -f $statusCode, $specificErrorMessage)
        }

        $deploymentGroupData = $ret.value[0]
        Write-Log ("Validated that the deployment group `"{0}`" exists" -f $config.DeploymentGroup)

        #Verify the user has manage permissions on the deployment group
        $deploymentGroupId = $deploymentGroupData.id

        $patchDeploymentGroupUrl = ("{0}/{1}/_apis/distributedtask/deploymentgroups/{2}?api-version={3}" -f $config.VSTSUrl, $config.TeamProject, $deploymentGroupId, $apiVersion)
        Write-Log "Patch deployment group url - $patchDeploymentGroupUrl"
        $headers += @{"Content-Type" = "application/json"}
        $requestBody = "{'name': '" + $config.DeploymentGroup + "'}"
        $patchDeploymentGroupErrorBlock = {
            $exception = $_
            $errorMessage = "Patch Deployment group failed: {0}"
            $failEarly = $false
            $inputsValidationErrorCode = $RM_Extension_Status.InputConfigurationError
            if($exception.Exception.Response)
            {
                switch($exception.Exception.Response.StatusCode.value__)
                {
                    403
                    {
                        $specificErrorMessage = ("Please ensure that the user has `"Manage`" permissions on the deployment group {0}" -f $config.DeploymentGroup)
                        $failEarly = $true
                    }
                    default
                    {
                        $specificErrorMessage = $unexpectedErrorMessage
                        $inputsValidationErrorCode = $RM_Extension_Status.GenericError
                    }
                }
                $errorMessage = ($errorMessageInitialPart -f $exception.Exception.Response.StatusCode.value__, $specificErrorMessage)
                Write-Log $errorMessage
            }
            else
            {
                $inputsValidationErrorCode = $RM_Extension_Status.MissingDependency
                $errorMessage = ($errorMessage -f $exception) + ". Please make sure that the virtual machine can access the Azure DevOps services."
                Write-Log $errorMessage $true
            }
            
            if($failEarly)
            {
                throw New-HandlerTerminatingError $inputsValidationErrorCode -Message $errorMessage
            }
        }

        $ret = Invoke-WithRetry -retryBlock {Invoke-RestMethod -Uri $patchDeploymentGroupUrl -Method "Patch" -Body $requestBody -Headers $headers} `
                                -retryCatchBlock {$null, $null = (& $patchDeploymentGroupErrorBlock)} -actionName "Patch deploymentgroup" `
                                -finalCatchBlock {$inputsValidationErrorCode, $errorMessage = (& $patchDeploymentGroupErrorBlock); throw New-HandlerTerminatingError $inputsValidationErrorCode -Message $errorMessage}

        Write-Log ("Validated that the user has `"Manage`" permissions on the deployment group {0}" -f $config.DeploymentGroup)

        Write-Log "Done validating inputs..."
        Add-HandlerSubStatus $RM_Extension_Status.SuccessfullyValidatedInputs.Code $RM_Extension_Status.SuccessfullyValidatedInputs.Message -operationName $RM_Extension_Status.SuccessfullyValidatedInputs.operationName

    }
    catch
    {
        Set-ErrorStatusAndErrorExit $_ $RM_Extension_Status.ValidatingInputs.operationName
    }
}

function Parse-VSTSUrl
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $vstsAccountUrl,
        [Parameter(Mandatory = $false)]
        [string] $patToken
    )

    $vstsUrl = $vstsAccountUrl
    $global:isOnPrem = $false
    $protocolHeader = ""
    $vstsAccountUrl = $vstsAccountUrl.TrimEnd('/')
    if (($vstsAccountUrl.StartsWith("https://")) -or ($vstsAccountUrl.StartsWith("http://"))) 
    {
        $parts = $vstsAccountUrl.Split(@('://'), [System.StringSplitOptions]::RemoveEmptyEntries)

        if ($parts.Count -gt 1) 
        {
            $protocolHeader = $parts[0] + "://"
            $urlWithoutProtocol = $parts[1].trim()
        }
        else
         {
            throw "Invalid account url. It cannot be just `"https://`""
        }
    }
    else
     {
        $urlWithoutProtocol = $vstsAccountUrl
    }

    if($protocolHeader -eq "")
    {
        Write-Log "Given input is not a valid URL. Assuming it is just the account name."
        $vstsUrl = "https://{0}.visualstudio.com" -f $vstsAccountUrl
        return $vstsUrl
    }

    $restCallUrl = $vstsAccountUrl + "/_apis/connectiondata"
    $headers = Get-RESTCallHeader $patToken
    $response = @{}
    $resp = $null
    $response.deploymentType = 'hosted'
    try
    {
        $resp = Invoke-WebRequest -Uri $restCallUrl -headers $headers -Method Get -MaximumRedirection 0 -ErrorAction Ignore -UseBasicParsing
    }
    catch
    {
        $errorMessage = "Failed to fetch the connection data for the url $restCallUrl."
        if($_.Exception.Response)
        {
            $errorMessage += "Status: $($_.Exception.Response.StatusCode.value__)"
        }
        Write-Log $errorMessage
    }
    if($resp)
    {
        if($resp.StatusCode -eq 302)
        {
            Write-Log "Failed to fetch the connection data for the url $restCallUrl : $($resp.StatusCode) $($resp.StatusDescription)"
        }
        else
        {
            $response = ($resp.Content | Out-String | ConvertFrom-Json)
        }
    }
    if (!$response.deploymentType -or $response.deploymentType -ne "hosted")
    {
        Write-Log "The Azure Devops server is onpremises" $true
        $global:isOnPrem = $true
        $subparts = $urlWithoutProtocol.Split('/', [System.StringSplitOptions]::RemoveEmptyEntries)
        if($subparts.Count -le 1)
        {
            throw "Invalid value for the input 'Azure DevOps Organization Url'. It should be in the format http(s)://<server>/<application>/<collection> for on-premise deployment."
        }
    }

    return $vstsUrl
}

function Format-TagsInput {
    [CmdletBinding()]
    param(
    [Parameter(Mandatory=$true, Position=0)]
    [psobject] $tagsInput
    )

    $tags = @()
    if($tagsInput.GetType().IsArray)
    {
        $tags = $tagsInput
    }
    elseif($tagsInput.GetType().Name -eq "hashtable")
    {
        [System.Collections.ArrayList]$tagsList = @()
        $tagsInput.Values | % { $tagsList.Add($_) > $null }
        $tags = $tagsList.ToArray()
    }
    elseif($tagsInput.GetType().Name -eq "String")
    {
        $tags = $tagsInput.Split(',', [System.StringSplitOptions]::RemoveEmptyEntries) | ForEach-Object -Process { $_.Trim() }
    }
    else
    {
        $message = "Tags input should either be a string, or an array of strings, or an object containing key-value pairs"
        throw New-HandlerTerminatingError $RM_Extension_Status.InputConfigurationError -Message $message
    }

    $uniqueTags = $tags | Sort-Object -Unique | Where { -not [string]::IsNullOrWhiteSpace($_) }

    #To handle null check, since ,$null does not return an array
    #else part for single element array
    if($null -eq $uniqueTags)
    {
        $uniqueTags = @()
    }
    elseif($uniqueTags.GetType().Name -eq "String")
    {
        $uniqueTags = @($uniqueTags)
    }
    #, single element array
    return ,$uniqueTags
}

function Verify-InputNotNull {
    [CmdletBinding()]
    param(
    [string] $inputKey,
    [string] $inputValue
    )

    if(-not $inputValue)
        {
            $message = "$inputKey should be specified"
            throw New-HandlerTerminatingError $RM_Extension_Status.InputConfigurationError -Message $message
        }
}