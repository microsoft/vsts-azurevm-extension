## Agent
$agentSetting = ".agent"
$downloadAPIVersion = "3.0-preview.2"
$targetsAPIVersion = "4.1-preview.1"
$agentZipName = "agent.zip"
$configCmd = "config.cmd"
$configCommonArgs = "--deploymentgroup --runasservice --unattended --replace --auth PAT "
$removeAgentArgs = " remove --unattended --auth PAT "
$defaultAgentWorkingFolder = "_work"
$legacyPlatformKey = "win7-x64"
$platform = "win-x64"
$agentWorkingFolder = "$env:SystemDrive\VSTSAgent"
$updateFileName = "EXTENSIONUPDATE"

## PS Version
$minPSVersionSupported = 3

## Variable Name 
$agentRemovalRequiredVarName = "removeExistingAgent"
$agentDownloadRequiredVarName = "downloadAgentZip"

## ReturnCodes
$returnSuccess = 0
