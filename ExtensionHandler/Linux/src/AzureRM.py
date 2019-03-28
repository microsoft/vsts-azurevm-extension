#! /usr/bin/python

import sys
import Utils.HandlerUtil as Util
import Utils.RMExtensionStatus as RMExtensionStatus
import os
import subprocess
import Utils.Constants as Constants
import DownloadDeploymentAgent
import ConfigureDeploymentAgent
import json
import time
from Utils.WAAgentUtil import waagent
from distutils.version import LooseVersion
import shutil

configured_agent_exists = False
agent_configuration_required = True
config = {}
root_dir = ''

def get_last_sequence_number_file_path():
  global root_dir
  return root_dir + '/LASTSEQNUM'

def get_last_sequence_number():
  last_seq_file = get_last_sequence_number_file_path()
  handler_utility.log('Reading last sequence number LASTSEQNUM file {0}'.format(last_seq_file))
  try:
    #Will raise IOError if file does not exist
    with open(last_seq_file) as f:
      contents = int(f.read())
      f.close()
      return contents
  except IOError as e:
    pass
  except ValueError as e:
    handler_utility.log('Contents of \'Last Sequence File\' not Integer')
    raise e
  return -1

def set_last_sequence_number():
  current_sequence_number = handler_utility._context._seq_no
  last_seq_file = get_last_sequence_number_file_path()
  handler_utility.log('Writing current sequence number {0} to LASTSEQNUM file {1}'.format(current_sequence_number, last_seq_file))
  try:
    with open(last_seq_file, 'w') as f:
      f.write(current_sequence_number)
      f.close()
  except Exception as e:
    pass

def set_extension_disabled_markup():
  markup_file = '{0}/{1}'.format(Constants.agent_working_folder, Constants.disable_markup_file_name)
  extension_settings_file_path = '{0}/{1}.settings'.format(handler_utility._context._config_dir , handler_utility._context._seq_no)
  handler_utility.log('Writing contents of {0} to {1}'.format(extension_settings_file_path, markup_file))
  try:
    shutil.copyfile(extension_settings_file_path, markup_file)
  except Exception as e:
    pass

def create_extension_update_file():
  handler_utility.log('Creating extension update file.')
  try:
    extension_update_file = '{0}/{1}'.format(Constants.agent_working_folder, Constants.update_file_name)
    with open(extension_update_file, 'w') as f:
      f.write('')
      f.close()
  except Exception as e:
    pass

def test_extension_disabled_markup():
  markup_file = '{0}/{1}'.format(Constants.agent_working_folder, Constants.disable_markup_file_name)
  handler_utility.log('Testing whether disabled markup file exists: ' + markup_file)
  if(os.path.isfile(markup_file)):
    return True
  else:
    return False

def remove_extension_disabled_markup():
  markup_file = '{0}/{1}'.format(Constants.agent_working_folder, Constants.disable_markup_file_name)
  handler_utility.log('Deleting disabled markup file if it exists' + markup_file)
  if(os.path.isfile(markup_file)):
    os.remove(markup_file)

def exit_with_code_zero():
  sys.exit(0)

def exit_with_non_zero_code(code):
  sys.exit(code)

def set_error_status_and_error_exit(e, operation_name, code = -1):
  handler_utility.set_handler_error_status(e, operation_name)
  # Log to command execution log file.
  handler_utility._set_log_file_to_command_execution_log()
  error_message = getattr(e,'message')
  # For unhandled exceptions that we might have missed to catch and specify error message.
  if(len(error_message) > Constants.ERROR_MESSAGE_LENGTH):
    error_message = error_message[:Constants.ERROR_MESSAGE_LENGTH]
  handler_utility.error('Error occured during {0}. {1}'.format(operation_name, error_message))
  exit_with_non_zero_code(code)

def check_python_version():
  version_info = sys.version_info
  version = '{0}.{1}'.format(version_info[0], version_info[1])
  if(LooseVersion(version) < LooseVersion('2.6')):
    code = RMExtensionStatus.rm_extension_status['PythonVersionNotSupported']['Code']
    message = RMExtensionStatus.rm_extension_status['PythonVersionNotSupported']['Message'].format(version)
    raise RMExtensionStatus.new_handler_terminating_error(code, message)

def check_systemd_exists():
  check_systemd_command = 'command -v systemctl'
  check_systemd_proc = subprocess.Popen(['/bin/bash', '-c', check_systemd_command], stdout = subprocess.PIPE, stderr = subprocess.PIPE)
  check_systemd_out, check_systemd_err = check_systemd_proc.communicate()
  return_code = check_systemd_proc.returncode
  handler_utility.log('Check systemd process exit code : {0}'.format(return_code))
  handler_utility.log('stdout : {0}'.format(check_systemd_out))
  handler_utility.log('srderr : {0}'.format(check_systemd_err))
  if(return_code == 0):
    handler_utility.log('systemd is installed on the machine.')
  else:
    code = RMExtensionStatus.rm_extension_status['SystemdNotFound']['Code']
    message = RMExtensionStatus.rm_extension_status['SystemdNotFound']['Message'].format(check_systemd_err)
    raise RMExtensionStatus.new_handler_terminating_error(code, message)

def validate_os():
  os_version = handler_utility.get_os_version()

  if(os_version['IsX64'] != True):
    code = RMExtensionStatus.rm_extension_status['ArchitectureNotSupported']['Code']
    message = RMExtensionStatus.rm_extension_status['ArchitectureNotSupported']['Message']
    raise RMExtensionStatus.new_handler_terminating_error(code, message)

def pre_validation_checks():
  try:
    validate_os()
  except Exception as e:
    set_error_status_and_error_exit(e, 'PreValidationCheck', Constants.ERROR_UNSUPPORTED_OS)
  
  try:
    check_python_version()
    check_systemd_exists()
  except Exception as e:
    set_error_status_and_error_exit(e, 'PreValidationCheck', Constants.ERROR_MISSING_DEPENDENCY)

  handler_utility.add_handler_sub_status(RMExtensionStatus.rm_extension_status['PreValidationCheckSuccess']['Code'], \
                                     RMExtensionStatus.rm_extension_status['PreValidationCheckSuccess']['Message'], \
                                     RMExtensionStatus.rm_extension_status['PreValidationCheckSuccess']['operationName'])

def install_dependencies():
  global config
  working_folder = config['AgentWorkingFolder']
  install_dependencies_path = os.path.join(working_folder, Constants.install_dependencies_script)
  install_dependencies_proc = subprocess.Popen(install_dependencies_path, stdout = subprocess.PIPE, stderr = subprocess.PIPE)
  install_out, install_err = install_dependencies_proc.communicate()
  return_code = install_dependencies_proc.returncode
  handler_utility.log('Install dependencies process exit code : {0}'.format(return_code))
  handler_utility.log('stdout : {0}'.format(install_out))
  handler_utility.log('srderr : {0}'.format(install_err))
  if(return_code == 0):
    handler_utility.log('Dependencies installed successfully.')
  else:
    raise Exception('Installing dependencies failed with error : {0}'.format(install_err))
  
def start_rm_extension_handler(operation):
  try:
    sequence_number = int(handler_utility._context._seq_no)
    last_sequence_number = get_last_sequence_number()
    if((sequence_number == last_sequence_number) and not(test_extension_disabled_markup())):
      handler_utility.log(RMExtensionStatus.rm_extension_status['SkippedInstallation']['Message'])
      handler_utility.log('Current sequence number : {0}, last sequence number : {1}'.format(sequence_number, last_sequence_number))
      handler_utility.add_handler_sub_status(RMExtensionStatus.rm_extension_status['SkippedInstallation']['Code'], \
                                     RMExtensionStatus.rm_extension_status['SkippedInstallation']['Message'], \
                                     RMExtensionStatus.rm_extension_status['SkippedInstallation']['operationName'])
      exit_with_code_zero()
    
    handler_utility.clear_status_file()

    handler_utility.set_handler_status(RMExtensionStatus.rm_extension_status['Initialized']['Code'], \
                                     RMExtensionStatus.rm_extension_status['Initialized']['Message'])
  except Exception as e:
    set_error_status_and_error_exit(e, RMExtensionStatus.rm_extension_status['Initializing']['operationName'], 1)

def parse_account_name(account_name, pat_token): 
  vsts_url = account_name.strip('/')

  account_name_prefix = Util.get_account_name_prefix(account_name)
  if(account_name_prefix == ''):
    vsts_url = 'https://{0}.visualstudio.com'.format(account_name)

  deployment_type = get_deployment_type(vsts_url, pat_token)
  if (deployment_type != 'hosted'):
    Constants.is_on_prem = True
    vsts_url_without_prefix = vsts_url[len(account_name_prefix):]
    parts = filter(lambda x: x!='', vsts_url_without_prefix.split('/'))
    if(len(parts) <= 1):
      raise Exception("Invalid value for the input 'Azure DevOps Organization url'. It should be in the format http(s)://<server>/<application>/<collection> for on-premise deployment.")

  return vsts_url

def get_deployment_type(vsts_url, pat_token):
  rest_call_url = vsts_url + '/_apis/connectiondata'
  response = Util.make_http_call(rest_call_url, 'GET', None, None, pat_token)
  if(response.status == Constants.HTTP_OK):
    connection_data = json.loads(response.read())
    if(connection_data.has_key('deploymentType')):
      return connection_data['deploymentType']
    else:
      return 'onPremises'
  else:
    handler_utility.log('Failed to fetch the connection data for the url {0}. Reason : {1} {2}'.format(rest_call_url, str(response.status), response.reason))
    return 'hosted'

def format_tags_input(tags_input):
  tags = []
  if(tags_input.__class__.__name__ == 'list'):
    tags = tags_input
  elif(tags_input.__class__.__name__ == 'dict'):
    tags = tags_input.values()
  elif(tags_input.__class__.__name__ == 'str' or tags_input.__class__.__name__ == 'unicode'):
    tags = tags_input.split(',')
  else:
    message = 'Tags input should be either a list or a dictionary'
    raise RMExtensionStatus.new_handler_terminating_error(RMExtensionStatus.rm_extension_status['ArgumentError'], message)
  ret_val = []
  temp = list(set(map(lambda x : x.strip(), tags)))
  for x in  temp:
    if(x!='' and x.lower() not in map(lambda y:y.lower(), ret_val)):
      ret_val.append(x)
  return ret_val

def validate_inputs(operation):
  global config
  try:
    invalid_pat_error_message = "Please make sure that the Personal Access Token entered is valid and has 'Deployment Groups - Read & manage' scope."
    inputs_validation_error_code = RMExtensionStatus.rm_extension_status['ArgumentError']
    unexpected_error_message = "Some unexpected error occured. Status code : {0}"

    # Verify the deployment group exists and the PAT has the required(Deployment Groups - Read & manage) scope
    # This is the first validation http call, so using Invoke-WebRequest instead of Invoke-RestMethod, because if the PAT provided is not a token at all(not even an unauthorized one) and some random value, then the call
    # would redirect to sign in page and not throw an exception. So, to handle this case.

    error_message_initial_part = "Could not verify that the deployment group '" + config['DeploymentGroup'] + "' exists in the project '" + config['TeamProject'] + "' in the specified organization '" + config['VSTSUrl'] +"'. Status: {0} Error: {1}. "
    specific_error_message = ""
    deployment_url = "{0}/{1}/_apis/distributedtask/deploymentgroups?name={2}&api-version={3}".format(config['VSTSUrl'], config['TeamProject'], config['DeploymentGroup'], Constants.projectAPIVersion)
    
    handler_utility.log("Url to check deployment group exists - {0}".format(deployment_url))

    response = Util.make_http_call(deployment_url, 'GET', None, None, config['PATToken'])

    if(response.status != Constants.HTTP_OK):
      error_message = error_message_initial_part.format(response.status, response.reason)
      if(response.status == Constants.HTTP_FOUND):
        specific_error_message = invalid_pat_error_message
        error_message = error_message_initial_part.format(response.status, "Redirected. ")
      elif(response.status == Constants.HTTP_UNAUTHORIZED):
        specific_error_message = invalid_pat_error_message
      elif(response.status == Constants.HTTP_FORBIDDEN):
        specific_error_message = "Please ensure that the user has 'View project-level information' permissions on the project '{0}'.".format(config['TeamProject'])
      elif(response.status == Constants.HTTP_NOTFOUND):
        specific_error_message = "Please make sure that you enter the correct organization name and verify that the project exists in the organization."
      else:
        specific_error_message = unexpected_error_message.format(response.status)
        inputs_validation_error_code = RMExtensionStatus.rm_extension_status['GenericError']
      
      raise RMExtensionStatus.new_handler_terminating_error(inputs_validation_error_code, error_message + specific_error_message)


    deployment_group_data = json.loads(response.read())

    if(('value' not in deployment_group_data) or len(deployment_group_data['value']) == 0):
      specific_error_message = "Please make sure that the deployment group {0} exists in the project {1}, and the user has 'Manage' permissions on the deployment group.".format(config['DeploymentGroup'], config['TeamProject'])
      raise RMExtensionStatus.new_handler_terminating_error(inputs_validation_error_code, error_message_initial_part.format(response.status, "Not found. ") + specific_error_message)

    deployment_group_id = deployment_group_data['value'][0]['id']
    handler_utility.log("Validated that the deployment group {0} exists".format(config['DeploymentGroup']))
    
    headers = {}
    headers['Content-Type'] = 'application/json'
    body = "{'name': '" + config['DeploymentGroup'] + "'}"
    patch_deployment_group_url = "{0}/{1}/_apis/distributedtask/deploymentgroups/{2}?api-version={3}".format(config['VSTSUrl'], config['TeamProject'], deployment_group_id, Constants.projectAPIVersion) 
    
    handler_utility.log("Url to check that the user has 'Manage' permissions on the deployment group - {0}".format(patch_deployment_group_url))
    response = Util.make_http_call(patch_deployment_group_url, 'PATCH', body, headers, config['PATToken'])

    if(response.status != Constants.HTTP_OK):
      if(response.status == Constants.HTTP_FORBIDDEN):
        specific_error_message = "Please ensure that the user has 'Manage' permissions on the deployment group {0}".format(config['DeploymentGroup'])
      else:
        specific_error_message = unexpected_error_message.format(str(response.status))
        inputs_validation_error_code = RMExtensionStatus.rm_extension_status['GenericError']

      raise RMExtensionStatus.new_handler_terminating_error(inputs_validation_error_code, error_message_initial_part.format(response.status, response.reason) + specific_error_message)
      

    handler_utility.log("Validated that the user has 'Manage' permissions on the deployment group '{0}'".format(config['DeploymentGroup']))

    handler_utility.log("Done validating inputs...")

    handler_utility.add_handler_sub_status(RMExtensionStatus.rm_extension_status['PreValidationCheckSuccess']['Code'], \
                                     RMExtensionStatus.rm_extension_status['PreValidationCheckSuccess']['Message'], \
                                     RMExtensionStatus.rm_extension_status['PreValidationCheckSuccess']['operationName'])

  except Exception as e:
    set_error_status_and_error_exit(e, RMExtensionStatus.rm_extension_status['PreValidationCheckSuccess']['operationName'], Constants.ERROR_CONFIGURATION)

def read_configutation_from_settings(operation):
  global config
  try:
    public_settings = handler_utility.get_public_settings()
    if(public_settings == None):
      public_settings = {}
    handler_utility.verify_public_settings_is_dict(public_settings)

    protected_settings = handler_utility.get_protected_settings()
    if(protected_settings == None):
      protected_settings = {}

    pat_token = ''
    if((protected_settings.__class__.__name__ == 'dict') and protected_settings.has_key('PATToken')):
      pat_token = protected_settings['PATToken']
    if((pat_token == '') and (public_settings.has_key('PATToken'))):
      pat_token = public_settings['PATToken']

    vsts_account_url = ''
    if(public_settings.has_key('AzureDevOpsOrganizationUrl')):
      vsts_account_url = public_settings['AzureDevOpsOrganizationUrl'].strip('/')
    elif(public_settings.has_key('VSTSAccountUrl')):
      vsts_account_url = public_settings['VSTSAccountUrl'].strip('/')
    elif(public_settings.has_key('VSTSAccountName')):
      vsts_account_url = public_settings['VSTSAccountName'].strip('/')
    handler_utility.verify_input_not_null('AzureDevOpsOrganizationUrl', vsts_account_url)
    vsts_url = vsts_account_url

    if(operation == Constants.ENABLE):
      vsts_url = parse_account_name(vsts_account_url, pat_token)
    handler_utility.log('Azure DevOps Organization Url : {0}'.format(vsts_url))

    team_project_name = ''
    if(public_settings.has_key('TeamProject')):
      team_project_name = public_settings['TeamProject']
    handler_utility.verify_input_not_null('TeamProject', team_project_name)
    handler_utility.log('Team Project : {0}'.format(team_project_name))

    deployment_group_name = ''
    if(public_settings.has_key('DeploymentGroup')):
      deployment_group_name = public_settings['DeploymentGroup']
    elif(public_settings.has_key('MachineGroup')):
      deployment_group_name = public_settings['MachineGroup']
    handler_utility.verify_input_not_null('DeploymentGroup', deployment_group_name)
    handler_utility.log('Deployment Group : {0}'.format(deployment_group_name))

    agent_name = ''
    if(public_settings.has_key('AgentName')):
      agent_name = public_settings['AgentName']
    handler_utility.log('Agent Name : {0}'.format(agent_name))

    tags_input = [] 
    if(public_settings.has_key('Tags')):
      tags_input = public_settings['Tags']
    handler_utility.log('Tags : {0}'.format(tags_input))
    tags = format_tags_input(tags_input)

    configure_agent_as_username = ''
    if(public_settings.has_key('UserName')):
      configure_agent_as_username = public_settings['UserName']

    handler_utility.log('Done reading config settings from file...')
    handler_utility.add_handler_sub_status(RMExtensionStatus.rm_extension_status['SuccessfullyReadSettings']['Code'], \
                                      RMExtensionStatus.rm_extension_status['SuccessfullyReadSettings']['Message'], \
                                      RMExtensionStatus.rm_extension_status['SuccessfullyReadSettings']['operationName'])
    config = {
             'VSTSUrl':vsts_url,
             'PATToken':pat_token, 
             'TeamProject':team_project_name, 
             'DeploymentGroup':deployment_group_name, 
             'AgentName':agent_name, 
             'Tags' : tags,
             'AgentWorkingFolder':Constants.agent_working_folder,
             'ConfigureAgentAsUserName': configure_agent_as_username
          }
  except Exception as e:
    set_error_status_and_error_exit(e, RMExtensionStatus.rm_extension_status['ReadingSettings']['operationName'], Constants.ERROR_CONFIGURATION)

def test_agent_configuration_required():
  global config
  return ConfigureDeploymentAgent.is_agent_configuration_required(config['VSTSUrl'], config['PATToken'], \
                      config['DeploymentGroup'], config['TeamProject'], config['AgentWorkingFolder'])

def execute_agent_pre_check():
  global configured_agent_exists, agent_configuration_required
  try:
    handler_utility.add_handler_sub_status(RMExtensionStatus.rm_extension_status['PreCheckingDeploymentAgent']['Code'], \
                                      RMExtensionStatus.rm_extension_status['PreCheckingDeploymentAgent']['Message'], \
                                      RMExtensionStatus.rm_extension_status['PreCheckingDeploymentAgent']['operationName'])
    configured_agent_exists = ConfigureDeploymentAgent.is_agent_configured(config['AgentWorkingFolder'])
    if(configured_agent_exists == True):
      agent_configuration_required = test_agent_configuration_required()
    handler_utility.add_handler_sub_status(RMExtensionStatus.rm_extension_status['PreCheckedDeploymentAgent']['Code'], \
                                      RMExtensionStatus.rm_extension_status['PreCheckedDeploymentAgent']['Message'], \
                                      RMExtensionStatus.rm_extension_status['PreCheckedDeploymentAgent']['operationName'])
  except Exception as e:
    set_error_status_and_error_exit(e, RMExtensionStatus.rm_extension_status['PreCheckingDeploymentAgent']['operationName'], 3)
  
def get_agent():
  global config
  try:
    handler_utility.add_handler_sub_status(RMExtensionStatus.rm_extension_status['DownloadingDeploymentAgent']['Code'], \
                                      RMExtensionStatus.rm_extension_status['DownloadingDeploymentAgent']['Message'], \
                                      RMExtensionStatus.rm_extension_status['DownloadingDeploymentAgent']['operationName'])
    
    handler_utility.log('Invoking function to download Deployment agent package...')
    DownloadDeploymentAgent.download_deployment_agent(config['VSTSUrl'], '', config['PATToken'], \
    config['AgentWorkingFolder'])
    handler_utility.log('Done downloading Deployment agent package...')

    handler_utility.add_handler_sub_status(RMExtensionStatus.rm_extension_status['DownloadedDeploymentAgent']['Code'], \
                                      RMExtensionStatus.rm_extension_status['DownloadedDeploymentAgent']['Message'], \
                                      RMExtensionStatus.rm_extension_status['DownloadedDeploymentAgent']['operationName'])
  except Exception as e:
    set_error_status_and_error_exit(e, RMExtensionStatus.rm_extension_status['DownloadingDeploymentAgent']['operationName'], 5)

def download_agent_if_required():
  global configured_agent_exists
  if(configured_agent_exists == False):
    get_agent()
  else:
    handler_utility.log('Skipping agent download as agent already exists.')
    handler_utility.add_handler_sub_status(RMExtensionStatus.rm_extension_status['SkippingDownloadDeploymentAgent']['Code'], \
                                      RMExtensionStatus.rm_extension_status['SkippingDownloadDeploymentAgent']['Message'], \
                                      RMExtensionStatus.rm_extension_status['SkippingDownloadDeploymentAgent']['operationName'])

def register_agent():
  global config, configured_agent_exists
  try:
    
    handler_utility.add_handler_sub_status(RMExtensionStatus.rm_extension_status['ConfiguringDeploymentAgent']['Code'], \
                                      RMExtensionStatus.rm_extension_status['ConfiguringDeploymentAgent']['Message'], \
                                      RMExtensionStatus.rm_extension_status['ConfiguringDeploymentAgent']['operationName'])
    handler_utility.log('Configuring Deployment agent...')
    ConfigureDeploymentAgent.configure_agent(config['VSTSUrl'], config['PATToken'], config['TeamProject'], \
      config['DeploymentGroup'], config['ConfigureAgentAsUserName'], config['AgentName'], config['AgentWorkingFolder'])
    handler_utility.log('Done configuring Deployment agent')
    
    handler_utility.add_handler_sub_status(RMExtensionStatus.rm_extension_status['ConfiguredDeploymentAgent']['Code'], \
                                      RMExtensionStatus.rm_extension_status['ConfiguredDeploymentAgent']['Message'], \
                                      RMExtensionStatus.rm_extension_status['ConfiguredDeploymentAgent']['operationName'])
  except Exception as e:
    set_error_status_and_error_exit(e, RMExtensionStatus.rm_extension_status['ConfiguringDeploymentAgent']['operationName'], 6)

def remove_existing_agent(operation):
  global config
  try:
    handler_utility.log('Agent removal started')
    try:
      ConfigureDeploymentAgent.remove_existing_agent(config['PATToken'], config['AgentWorkingFolder'])
      
      handler_utility.add_handler_sub_status(RMExtensionStatus.rm_extension_status['RemovedAgent']['Code'], \
                                      RMExtensionStatus.rm_extension_status['RemovedAgent']['Message'], \
                                      RMExtensionStatus.rm_extension_status['RemovedAgent']['operationName'])
      DownloadDeploymentAgent.clean_agent_folder()
    except Exception as e:
      if(('Reason' in dir(e) and getattr(e, 'Reason') == 'UnConfigFailed') and (os.access(config['AgentWorkingFolder'], os.F_OK))):      
        handler_utility.add_handler_sub_status(RMExtensionStatus.rm_extension_status['UnConfiguringDeploymentAgentFailed']['Code'], \
                                      RMExtensionStatus.rm_extension_status['UnConfiguringDeploymentAgentFailed']['Message'], \
                                      RMExtensionStatus.rm_extension_status['UnConfiguringDeploymentAgentFailed']['operationName'])

        DownloadDeploymentAgent.clean_agent_folder()
      else:
        raise e
    ConfigureDeploymentAgent.setting_params = {}
  except Exception as e:
    set_error_status_and_error_exit(e, RMExtensionStatus.rm_extension_status['Uninstalling']['operationName'], 7)

def remove_existing_agent_if_required():
  global configured_agent_exists, agent_configuration_required
  if((configured_agent_exists == True) and (agent_configuration_required == True)):
    handler_utility.log('Remove existing configured agent')
    remove_existing_agent(Constants.ENABLE)
    #Execution has reached till here means that either the agent was removed successfully, or we renamed the agent folder successfully. 
    configured_agent_exists = False

def configure_agent_if_required():
  if(agent_configuration_required):
    register_agent()
  else:
    handler_utility.add_handler_sub_status(RMExtensionStatus.rm_extension_status['SkippingAgentConfiguration']['Code'], \
                                      RMExtensionStatus.rm_extension_status['SkippingAgentConfiguration']['Message'], \
                                      RMExtensionStatus.rm_extension_status['SkippingAgentConfiguration']['operationName'])

def add_agent_tags():

  try:
    handler_utility.add_handler_sub_status(RMExtensionStatus.rm_extension_status['AddingAgentTags']['Code'], \
                                      RMExtensionStatus.rm_extension_status['AddingAgentTags']['Message'], \
                                      RMExtensionStatus.rm_extension_status['AddingAgentTags']['operationName'])

    if(config['Tags'] !=None and len(config['Tags']) > 0):
      handler_utility.log('Adding tags to configured agent - {0}'.format(str(config['Tags'])))
      tags_string = json.dumps(config['Tags'], ensure_ascii = False)
      ConfigureDeploymentAgent.add_agent_tags(config['VSTSUrl'], config['TeamProject'], \
      config['PATToken'], config['AgentWorkingFolder'], tags_string)
      
      handler_utility.add_handler_sub_status(RMExtensionStatus.rm_extension_status['AgentTagsAdded']['Code'], \
                                      RMExtensionStatus.rm_extension_status['AgentTagsAdded']['Message'], \
                                      RMExtensionStatus.rm_extension_status['AddingAgentTags']['operationName'])
    else:
      handler_utility.log('No tags provided for agent')
  except Exception as e:
      set_error_status_and_error_exit(e, RMExtensionStatus.rm_extension_status['AddingAgentTags']['operationName'], 8)

def test_extension_settings_are_same_as_previous_version(operation):
  try:
    old_extension_settings_file_path = "{0}/{1}".format(Constants.agent_working_folder, Constants.disable_markup_file_name)
    old_extension_settings_file_exists = os.path.isfile(old_extension_settings_file_path)
    if(old_extension_settings_file_exists):
      extension_settings_file_path = '{0}/{1}.settings'.format(handler_utility._context._config_dir , handler_utility._context._seq_no)

      with open(old_extension_settings_file_path, 'r') as f:
        old_extension_settings_file_contents = f.read()
        old_extension_public_settings = json.loads(old_extension_settings_file_contents)
        old_extension_public_settings = old_extension_public_settings['runtimeSettings'][0]['handlerSettings']['publicSettings']

      with open(extension_settings_file_path, 'r') as f:
        extension_settings_file_contents = f.read()
        extension_public_settings = json.loads(extension_settings_file_contents)
        extension_public_settings = extension_public_settings['runtimeSettings'][0]['handlerSettings']['publicSettings']

      if(Util.ordered_json_object(old_extension_public_settings) == Util.ordered_json_object(extension_public_settings)):
        handler_utility.log('Old and new extension version settings are same.')
        return True
      else:
        handler_utility.log('Old and new extension version settings are not same.')
        handler_utility.log('Old extension version settings: {0}'.format(old_extension_public_settings))
        handler_utility.log('New extension version settings: {0}'.format(extension_public_settings))
    else:
      handler_utility.log('Old extension settings file does not exist in the agent directory. Will continue with enable.')
    return False
  except Exception as e:
    set_error_status_and_error_exit(e, RMExtensionStatus.rm_extension_status['SkippingEnableSameSettingsAsPreviousVersion']['operationName'], 9)

def enable():
  input_operation = Constants.ENABLE
  start_rm_extension_handler(input_operation)
  read_configutation_from_settings(input_operation)
  if(test_extension_settings_are_same_as_previous_version(input_operation)):
    handler_utility.log("Skipping extension enable.")
    handler_utility.add_handler_sub_status(RMExtensionStatus.rm_extension_status['SkippingEnableSameSettingsAsPreviousVersion']['Code'], \
                                     RMExtensionStatus.rm_extension_status['SkippingEnableSameSettingsAsPreviousVersion']['Message'], \
                                     RMExtensionStatus.rm_extension_status['SkippingEnableSameSettingsAsPreviousVersion']['operationName'])
  else:
    validate_inputs(input_operation)
    ConfigureDeploymentAgent.set_logger(handler_utility.log)
    DownloadDeploymentAgent.set_logger(handler_utility.log)
    execute_agent_pre_check()
    remove_existing_agent_if_required()
    download_agent_if_required()
    install_dependencies()
    configure_agent_if_required()
    handler_utility.set_handler_status(RMExtensionStatus.rm_extension_status['Installed']['Code'], \
                                       RMExtensionStatus.rm_extension_status['Installed']['Message'])
    add_agent_tags()
    handler_utility.log('Extension is enabled.')
    handler_utility.log('Removing disable markup file..')
  
  handler_utility.set_handler_status(RMExtensionStatus.rm_extension_status['Enabled']['Code'], \
                                     RMExtensionStatus.rm_extension_status['Enabled']['Message'], \
                                     'success')

  set_last_sequence_number()
  remove_extension_disabled_markup()

def disable():
  ConfigureDeploymentAgent.set_logger(handler_utility.log)
  handler_utility.log('Disable command is no-op for agent')
  handler_utility.log('Creating a markup file...')
  set_extension_disabled_markup()
  
  handler_utility.set_handler_status(RMExtensionStatus.rm_extension_status['Disabled']['Code'], \
                                     RMExtensionStatus.rm_extension_status['Disabled']['Message'], \
                                     'success')

def uninstall():
  global config, configured_agent_exists
  operation = Constants.UNINSTALL
  read_configutation_from_settings(operation)
  configured_agent_exists = ConfigureDeploymentAgent.is_agent_configured(config['AgentWorkingFolder'])
  extension_update_file = '{0}/{1}'.format(Constants.agent_working_folder, Constants.update_file_name)
  is_udpate_scenario = os.path.isfile(extension_update_file)
  if(not(is_udpate_scenario)):  
    if(configured_agent_exists == True):
      remove_existing_agent(operation)
  else:
    handler_utility.log('Extension update scenario. Deleting the file {0}/{1}'.format(Constants.agent_working_folder, Constants.update_file_name))
    os.remove(extension_update_file)
  
  handler_utility.set_handler_status(RMExtensionStatus.rm_extension_status['Uninstalling']['Code'], \
                                     RMExtensionStatus.rm_extension_status['Uninstalling']['Message'], \
                                     'success')

def update():
  create_extension_update_file()

def main():
  waagent.LoggerInit('/var/log/waagent.log','/dev/stdout')
  if(len(sys.argv) == 2):
    global handler_utility
    handler_utility = Util.HandlerUtility(waagent.Log, waagent.Error)
    operation = sys.argv[1]
    #Settings are read from file in do_parse_context, and protected settings are also removed from the file in this function
    handler_utility.do_parse_context(operation)
    try:
      global root_dir
      root_dir = os.getcwd()
      
      if(sys.argv[1] not in Constants.input_arguments_dict):
        raise Exception("Internal Error: Invalid argument provided to the script")

      input_operation = Constants.input_arguments_dict[sys.argv[1]]
      
      pre_validation_checks()

      if(input_operation == Constants.ENABLE):
        enable()
      elif(input_operation == Constants.DISABLE):
        disable()
      elif(input_operation == Constants.UNINSTALL):
        uninstall()
      elif(input_operation == Constants.UPDATE):
        update()

      exit_with_code_zero()
    except Exception as e:
      set_error_status_and_error_exit(e, 'main', 9)

if(__name__ == '__main__'):
  main()

