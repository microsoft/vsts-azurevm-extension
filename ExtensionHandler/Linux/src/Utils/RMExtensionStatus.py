#!/usr/bin/python
import Constants

rm_terminating_error_id = 'RMHandlerTerminatingError'

rm_extension_status = {
  'Installing' : {
    'Code' : 1,
    'Message' : 'Installing and configuring deployment agent.'
  },
  'Installed' : {
    'Code' : 2,
    'Message' : 'Configured deployment agent successfully.'
  },
  'Initializing' : {
    'Code' : 3,
    'Message' : 'Initializing extension.',
    'operationName' : 'Initialization'
  },
  'Initialized' : {
    'Code' : 4,
    'Message' : 'Initialized extension successfully.',
    'operationName' : 'Initialization'
  },
  'PreCheckingDeploymentAgent' : {
    'Code' : 5,
    'Message' : 'Checking whether an agent is already existing.',
    'operationName' : 'Check existing Agent'
  },
  'PreCheckedDeploymentAgent' : {
    'Code' : 6,
    'Message' : 'Checked for existing deployment agent.',
    'operationName' : 'Check existing agent'
  },
  'SkippingDownloadDeploymentAgent' : {
    'Code' : 7,
    'Message' : 'Skipping download of deployment agent.',
    'operationName' : 'Agent download'
  },
  'DownloadingDeploymentAgent' : {
    'Code' : 8,
    'Message' : 'Downloading deployment agent package.',
    'operationName' : 'Agent download'
  },
  'DownloadedDeploymentAgent' : {
    'Code' : 9,
    'Message' : 'Downloaded deployment agent package.',
    'operationName' : 'Agent download'
  },
  'RemovingAndConfiguringDeploymentAgent' : {
    'Code' : 10,
    'Message' : 'Removing existing deployment agent and configuring afresh.',
    'operationName' : 'Agent configuration'
  },
  'ConfiguringDeploymentAgent' : {
    'Code' : 11,
    'Message' : 'Configuring deployment agent.',
    'operationName' : 'Agent configuration'
  },
  'ConfiguredDeploymentAgent' : {
    'Code' : 12,
    'Message' : 'Configured deployment agent successfully.',
    'operationName' : 'Agent configuration'
  },
  'ReadingSettings' : {
    'Code' : 13,
    'Message' : 'Reading config settings from file.',
    'operationName' : 'Read config settings'
  },
  'SuccessfullyReadSettings' : {
    'Code' : 14,
    'Message' : 'Successfully read config settings from file.',
    'operationName' : 'Read config settings'
  },
  'SkippedInstallation' : {
    'Code' : 15,
    'Message' : 'No change in config settings or VM has just been rebooted. Skipping initialization.',
    'operationName' : 'Initialization'
  },
  'Disabled' : {
    'Code' : 16,
    'Message' : 'Disabled extension. However, Team services agent would continue to be registered with Azure DevOps and will keep running.',
    'operationName' : 'Disable'
  },
  'Uninstalling' : {
    'Code' : 17,
    'Message' : 'Uninstalling extension.',
    'operationName' : 'Uninstall'
  },
  'RemovedAgent' : {
    'Code' : 18,
    'Message' : 'Removed deployment agent successfully from deployment group.',
    'operationName' : 'Uninstall'
  },
  'CheckingAgentReConfigurationRequired' : {
    'Code' : 19,
    'Message' : 'Checking if re-configuration is required for existing agent by comparing agent settings.',
    'operationName' : 'Agent configuration'
  },
  'AgentReConfigurationRequiredChecked' : {
    'Code' : 20,
    'Message' : 'Checked if re-configuration is required for existing agent.',
    'operationName' : 'Agent configuration'
  },
  'SkippingAgentConfiguration' : {
    'Code' : 21,
    'Message' : 'An agent is already running with same settings, skipping agent configuration.',
    'operationName' : 'Agent configuration'
  },
  'AgentTagsAdded' : {
    'Code' : 23,
    'Message' : 'Successfully added the tags to deployment agent.',
    'operationName' : 'Agent tags'
  },
  'AddingAgentTags' : {
    'Code' : 24,
    'Message' : 'Adding agent tags.',
    'operationName' : 'Add agent tags'
  },
  'UnConfiguringDeploymentAgentFailed' : {
    'Code' : 25,
    'Message' : '[WARNING] The deployment agent {0} could not be uninstalled. Ensure to remove it manually from its deployment group in Azure DevOps.',
    'operationName' : 'Unconfigure existing agent'
  },
  'Enabled' : {
    'Code' : 26,
    'Message' : 'The extension has been enabled successfully.',
    'operationName' : 'Enable'
  },
  'Updated' : {
    'Code' : 27,
    'Message' : 'The extension has been updated successfully.',
    'operationName' : 'Updated'
  },
  'SkippingEnableSameSettingsAsPreviousVersion' : {
    'Code' : 28,
    'Message' : 'The extension settings are the same as the previous version. Skipping extension enable.',
    'operationName' : 'Skip enable'
  },
  'ValidatingInputs': {
    'Code' : 29,
    'Message': 'Validating Inputs',
    'operationName': 'Inputs validation'
  },
  'SuccessfullyValidatedInputs' : {
    'Code' : 30,
    'Message' : 'Successfully validated inputs',
    'operationName': 'Inputs validation'
  },
  'PreValidationCheck': {
    'Code': 31,
    'Message': 'Validating dependecies',
    'operationName': 'Pre-Validation Checks'
  },
  'PreValidationCheckSuccess': {
    'Code': 32,
    'Message': 'Successfully validated dependecies',
    'operationName': 'Pre-Validation Checks'
  },
  'ComparingWithPreviousSettings': {
    'Code': 33,
    'Message': 'Comparing settings with previous settings',
    'operationName': 'Settings Comparison'
  },

  #
  # Warnings
  #
  'GenericWarning' : 100, 
  #
  # Errors
  #
  'GenericError' : 1000, # The message for this error is provided by the specific exception
  'InstallError' : 1001, # The message for this error is provided by the specific exception
  'ArchitectureNotSupported' : {
    'Code' : Constants.ERROR_UNSUPPORTED_OS,
    'Message' : 'The current CPU architecture is not supported. Deployment agent requires x64 architecture.'
  },
  'PythonVersionNotSupported' : {
    'Code' : Constants.ERROR_MISSING_DEPENDENCY,
    'Message' : 'Installed Python version is {0}. Minimum required version is 2.6.'
  },
  'SystemdNotFound': {
    'Code' : Constants.ERROR_MISSING_DEPENDENCY,
    'Message': 'Could not find systemd on the machine. Error message: {0}'
  },
  #
  # ArgumentError indicates a problem in the input provided by the user. The message for the error is provided by the specific exception
  #
  'ArgumentError' : Constants.ERROR_CONFIGURATION,
  'AgentUnConfigureFailWarning' : 'There are some warnings in uninstalling the already existing agent. Check \"Detailed Status\" for more details.'
}


def new_handler_terminating_error(code, message):
  e = Exception(message)
  setattr(e, 'Code', code)
  setattr(e, 'Message', message)
  setattr(e, 'ErrorId', rm_terminating_error_id)
  return e

