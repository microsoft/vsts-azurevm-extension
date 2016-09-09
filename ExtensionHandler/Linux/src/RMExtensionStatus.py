#!/usr/bin/python


global rm_extension_status
global rm_terminating_error_id 
rm_terminating_error_id= 'RMHandlerTerminatingError'

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
    'Code' : 3,
    'Message' : 'Reading config settings from file.',
    'operationName' : 'Read Config settings'
  },
  'SuccessfullyReadSettings' : {
    'Code' : 4,
    'Message' : 'Successfully read config settings from file.',
    'operationName' : 'Read Config settings'
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
  #
  # ArgumentError indicates a problem in the input provided by the user. The message for the error is provided by the specific exception
  #
  'ArgumentError' : 1100 
}
  
