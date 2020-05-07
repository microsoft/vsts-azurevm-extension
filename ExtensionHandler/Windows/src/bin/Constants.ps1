## Agent
$agentSetting = ".agent"
$downloadAPIVersion = "3.0-preview.2"
$apiVersion = "5.0-preview.1"

$agentZipName = "agent.zip"
$configCmd = "config.cmd"
$configCommonArgs = "--unattended --replace --auth PAT "
$removeAgentArgs = " remove --unattended --auth PAT "
$defaultAgentWorkFolder = "_work"
$platform = "win-x64"
$agentWorkingFolderOld = "$env:SystemDrive\VSTSAgent"
$agentWorkingFolderNew = "$env:SystemDrive\AzurePiplinesAgent_Extension"
$agentWorkingFolderPipelines = "$env:SystemDrive\ElasticPoolAgent"
$agentNameCharacterLimit = 64

# markup files
$disabledMarkupFile = "EXTENSIONDISABLED"
$updateFileName = "EXTENSIONUPDATE"

## PS Version
$minPSVersionSupported = 3

## Variable Name 
$agentRemovalRequiredVarName = "removeExistingAgent"
$agentDownloadRequiredVarName = "downloadAgentZip"

## ReturnCodes
$returnSuccess = 0

#Maximum length for exception messages, beyond which it will get truncated
$maximumExceptionMessageLength = 400