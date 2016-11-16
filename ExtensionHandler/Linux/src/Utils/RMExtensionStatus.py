#!/usr/bin/python

rm_terminating_error_id = 'RMHandlerTerminatingError'

rm_extension_status = {
  'Installing' : {
    'Code' : 1,
    'Message' : 'Installing and configuring Deployment agent.' 
  },
  'Installed' : {
    'Code' : 2,
    'Message' : 'Configured Deployment agent successfully.' 
  },
  'Initializing' : {
    'Code' : 3,
    'Message' : 'Initializing RM extension.',
    'operationName' : 'Initialization'
  },
  'Initialized' : {
    'Code' : 4,
    'Message' : 'Done Initializing RM extension.',
    'operationName' : 'Initialization'
  },
  'PreCheckingDeploymentAgent' : {
    'Code' : 5,
    'Message' : 'Checking whether an agent is already exising.',
    'operationName' : 'Check existing Agent'
  },
  'PreCheckedDeploymentAgent' : {
    'Code' : 6,
    'Message' : 'Checked for exising deployment agent.',
    'operationName' : 'Check existing Agent'
  },
  'SkippingDownloadDeploymentAgent' : {
    'Code' : 7,
    'Message' : 'Skipping download of deployment agent.',
    'operationName' : 'Agent download'
  },
  'DownloadingDeploymentAgent' : {
    'Code' : 8,
    'Message' : 'Downloading Deployment agent package.',
    'operationName' : 'Agent download'
  },
  'DownloadedDeploymentAgent' : {
    'Code' : 9,
    'Message' : 'Downloaded Deployment agent package.',
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
    'Message' : 'Configured Deployment agent successfully.',
    'operationName' : 'Agent configuration'
  },
  'ReadingSettings' : {
    'Code' : 13,
    'Message' : 'Reading config settings from file.',
    'operationName' : 'Read Config settings'
  },
  'SuccessfullyReadSettings' : {
    'Code' : 14,
    'Message' : 'Successfully read config settings from file.',
    'operationName' : 'Read Config settings'
  },
  'SkippedInstallation' : {
    'Code' : 15,
    'Message' : 'Same config settings have already been processed. This can happen if extension has been set again without changing any config settings or if VM has been rebooted. Skipping this time.',
    'operationName' : 'Initialization'
  },
  'Disabled' : {
    'Code' : 16,
    'Message' : 'Disabled extension. This will have no affect on team services agent. It will keep running and will still be registered with VSTS.',
    'operationName' : 'Disable'
  },
  'Uninstalling' : {
    'Code' : 17,
    'Message' : 'Uninstalling extension.',
    'operationName' : 'Uninstall'
  },
  'RemovedAgent' : {
    'Code' : 18,
    'Message' : 'Uninstalling extension has no affect on team services agent. It will keep running and will still be registered with VSTS.',
    'operationName' : 'Uninstall'
  },
  'CheckingAgentReConfigurationRequired' : {
    'Code' : 19,
    'Message' : 'Checking if re-configuration is required for existing agent by comparing existing agent settings',
    'operationName' : 'Agent Configuration'
  },
  'AgentReConfigurationRequiredChecked' : {
    'Code' : 20,
    'Message' : 'Checked if re-configuration is required for existing agent',
    'operationName' : 'Agent Configuration'
  },
  'SkippingAgentConfiguration' : {
    'Code' : 21,
    'Message' : 'An agent is already running with same settings, skipping agent configuration',
    'operationName' : 'Agent Configuration'
  },
  'AgentTagsAdded' : {
    'Code' : 23,
    'Message' : 'Successfully added the tags to deployment agent',
    'operationName' : 'Agent Tags'
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
    'Code' : 1002,
    'Message' : 'The current CPU architecture is not supported. RM agent requires x64 architecture.'
  },
  'PythonVersionNotSupported' : {
    'Code' : 1003,
    'Message' : 'Installed Python version is {0}. Minimum required version is 2.6'
  },
  'LinuxDistributionNotSupported' : {
    'Code' : 1004,
    'Message' : 'Linux distribution on system is {0} {1}. Only Linux distributions Ubuntu 16.04 and Red Hat Enterprise Linux Server 7.2 are supported.'
  },
  #
  # ArgumentError indicates a problem in the input provided by the user. The message for the error is provided by the specific exception
  #
  'ArgumentError' : 1100 
}


def new_handler_terminating_error(code, message):
  e = Exception(message)
  setattr(e, 'Code', code)
  setattr(e, 'Message', message)
  setattr(e, 'ErrorId', rm_terminating_error_id)
  return e

