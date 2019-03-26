## Agent
$agentSetting = ".agent"
$downloadAPIVersion = "3.0-preview.2"
$apiVersion = "5.0-preview.1"

$agentZipName = "agent.zip"
$configCmd = "config.cmd"
$configCommonArgs = "--deploymentgroup --runasservice --unattended --replace --auth PAT "
$removeAgentArgs = " remove --unattended --auth PAT "
$defaultAgentWorkFolder = "_work"
$platform = "win-x64"
$agentWorkingFolderOld = "$env:SystemDrive\VSTSAgent"
$agentWorkingFolderNew = "$env:SystemDrive\AzurePiplinesAgent_Extension"
$updateFileName = "EXTENSIONUPDATE"

# markup file to detect whether extension has been previously disabled
$disabledMarkupFile = "EXTENSIONDISABLED"

## PS Version
$minPSVersionSupported = 3

## Variable Name 
$agentRemovalRequiredVarName = "removeExistingAgent"
$agentDownloadRequiredVarName = "downloadAgentZip"

## ReturnCodes
$returnSuccess = 0
