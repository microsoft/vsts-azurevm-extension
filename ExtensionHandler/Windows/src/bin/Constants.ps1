## Agent
$agentSetting = ".agent"
$downloadAPIVersion = "3.0-preview.2"
$agentZipName = "agent.zip"
$configCmd = "config.cmd"
$configCommonArgs = "--deploymentgroup --runasservice --unattended --replace --auth PAT "
$removeAgentArgs = " remove --unattended --auth PAT "
$defaultAgentWorkingFolder = "_work"

## PS Version
$minPSVersionSupported = 3

## Variable Name 
$agentRemovalRequiredVarName = "removeExistingAgent"
$agentDownloadRequiredVarName = "downloadAgentZip"

## ReturnCodes
$returnSuccess = 0
