## Agent
$agentSetting = ".agent"
$downloadAPIVersion = "3.0-preview.2"
$agentZipName = "agent.zip"
$configCmd = "config.cmd"
$configCommonArgs = "--deploymentagent --runasservice --unattended --auth PAT "
$removeAgentArgs = " remove --unattended --auth PAT "

## PS Version
$minPSVersionSupported = 3

## Variable Name 
$agentRemovalRequiredVarName = "removeExistingAgent"
$agentDownloadRequiredVarName = "downloadAgentZip"

## ReturnCodes
$returnSuccess = 0