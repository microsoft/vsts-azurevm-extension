#! /usr/bin/python3
#todo
#1. agent rename
#2. retries
#3. get command execution log summary
#4. api versions merge and everywhere

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
import shutil
from Utils.WAAgentUtil import waagent
from Utils.GlobalSettings import proxy_config
from distutils.version import LooseVersion
from time import sleep
from urllib.parse import quote
import urllib.request, urllib.parse, urllib.error
import shlex

MAX_RETRIES = 3

configured_agent_exists = False
agent_configuration_required = True
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

def exit_with_code(code):
  sys.exit(code)

def set_error_status_and_error_exit(e, operation_name, code = -1):
  handler_utility.set_handler_error_status(e, operation_name)
  # Log to command execution log file.
  handler_utility._set_log_file_to_command_execution_log()
  error_message = str(e)
  # For unhandled exceptions that we might have missed to catch and specify error message.
  if(len(error_message) > Constants.ERROR_MESSAGE_LENGTH):
    error_message = error_message[:Constants.ERROR_MESSAGE_LENGTH]
  handler_utility.error('Error occured during {0}. {1}'.format(operation_name, error_message))
  exit_with_code(code)

def check_python_version():
  version_info = sys.version_info
  version = '{0}.{1}'.format(version_info[0], version_info[1])
  if(LooseVersion(version) < LooseVersion('2.6')):
    code = RMExtensionStatus.rm_extension_status['MissingDependency']
    message = 'Installed Python version is {0}. Minimum required version is 2.6.'.format(version)
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
    code = RMExtensionStatus.rm_extension_status['MissingDependency']
    message = 'Could not find systemd on the machine. Error message: {0}'.format(check_systemd_err)
    raise RMExtensionStatus.new_handler_terminating_error(code, message)

def validate_os():
  os_version = handler_utility.get_os_version()

  if(os_version['IsX64'] != True):
    code = RMExtensionStatus.rm_extension_status['UnSupportedOS']
    message = 'The current CPU architecture is not supported. Deployment agent requires x64 architecture.'
    raise RMExtensionStatus.new_handler_terminating_error(code, message)

def pre_validation_checks():
  try:
    validate_os()
    check_python_version()
    check_systemd_exists()
  except Exception as e:
    set_error_status_and_error_exit(e, RMExtensionStatus.rm_extension_status['PreValidationCheck']['operationName'], e.__getattribute__('Code'))

  handler_utility.add_handler_sub_status(Util.HandlerSubStatus('PreValidationCheckSuccess'))

def install_dependencies(config):
  num_of_retries = 5
  sleep_interval_in_sec = 5
  working_folder = config['AgentWorkingFolder']
  install_dependencies_path = os.path.join(working_folder, Constants.install_dependencies_script)
  for i in range(num_of_retries):
    env = {
        **os.environ
    }
    if ('ProxyUrl' in proxy_config):
      proxy_url = proxy_config['ProxyUrl']
      env["http_proxy"] = proxy_url
      env["https_proxy"] = proxy_url
    install_dependencies_proc = subprocess.Popen(install_dependencies_path, stdout = subprocess.PIPE, stderr = subprocess.PIPE, env=env)
    install_out, install_err = install_dependencies_proc.communicate()
    return_code = install_dependencies_proc.returncode
    handler_utility.log('Install dependencies process exit code : {0}'.format(return_code))
    handler_utility.log('stdout : {0}'.format(install_out))
    handler_utility.log('srderr : {0}'.format(install_err))
    if(return_code == 0):
      handler_utility.log('Dependencies installed successfully.')
      break
    else:
      error_message = 'Installing dependencies failed with error : {0}'.format(install_err)
      if(i == (num_of_retries -1)):
        raise Exception(error_message)
      else:
        handler_utility.log(error_message)
    sleep(sleep_interval_in_sec)
  handler_utility.add_handler_sub_status(Util.HandlerSubStatus('InstalledDependencies'))
  
def compare_sequence_number():
  try:
    sequence_number = int(handler_utility._context._seq_no)
    last_sequence_number = get_last_sequence_number()
    if((sequence_number == last_sequence_number) and not(test_extension_disabled_markup())):
      handler_utility.log(RMExtensionStatus.rm_extension_status['SkippedInstallation']['Message'])
      handler_utility.log('Skipping enable since seq numbers match. Seq number: {0}.'.format(sequence_number))
      exit_with_code(0)

  except Exception as e:
    handler_utility.log('Sequence number check failed: {0}.'.format(e))

def parse_account_name(account_name, pat_token): 
  vsts_url = account_name.strip('/')

  account_name_prefix = Util.get_url_prefix(account_name)
  if(account_name_prefix == ''):
    vsts_url = 'https://{0}.visualstudio.com'.format(account_name)

  deployment_type = get_deployment_type(vsts_url, pat_token)
  if (deployment_type != 'hosted'):
    Constants.is_on_prem = True
    vsts_url_without_prefix = vsts_url[len(account_name_prefix):]
    parts = [x for x in vsts_url_without_prefix.split('/') if x!='']
    if(len(parts) <= 1):
      raise Exception("Invalid value for the input 'Azure DevOps Organization url'. It should be in the format http(s)://<server>/<application>/<collection> for on-premise deployment.")

  return vsts_url

def get_deployment_type(vsts_url, pat_token):
  rest_call_url = vsts_url + '/_apis/connectiondata'
  response = Util.make_http_request(rest_call_url, 'GET', None, None, pat_token)
  if(response.status == Constants.HTTP_OK):
    connection_data = json.loads(str(response.read(), 'utf-8'))
    if('deploymentType' in connection_data):
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
    tags = list(tags_input.values())
  elif(tags_input.__class__.__name__ == 'str' or tags_input.__class__.__name__ == 'unicode'):
    tags = tags_input.split(',')
  else:
    message = 'Tags input should be either a list or a dictionary'
    raise RMExtensionStatus.new_handler_terminating_error(RMExtensionStatus.rm_extension_status['InputConfigurationError'], message)
  ret_val = []
  temp = list(set([x.strip() for x in tags]))
  for x in  temp:
    if(x!='' and x.lower() not in [y.lower() for y in ret_val]):
      ret_val.append(x)
  return ret_val

def validate_inputs(config):
  try:
    invalid_pat_error_message = "Please make sure that the Personal Access Token entered is valid and has 'Deployment Groups - Read & manage' scope."
    inputs_validation_error_code = RMExtensionStatus.rm_extension_status['InputConfigurationError']
    unexpected_error_message = "Some unexpected error occured. Status code : {0}"
    error_message_initial_part = "Could not verify that the deployment group '" + config['DeploymentGroup'] + "' exists in the project '" + config['TeamProject'] + "' in the specified organization '" + config['VSTSUrl'] +"'. Status: {0} Error: {1}. "

    # Verify the deployment group exists and the PAT has the required(Deployment Groups - Read & manage) scope
    # This is the first validation http call, so using Invoke-WebRequest instead of Invoke-RestMethod, because if the PAT provided is not a token at all(not even an unauthorized one) and some random value, then the call
    # would redirect to sign in page and not throw an exception. So, to handle this case.

    specific_error_message = ""
    get_deployment_group_url = "{0}/{1}/_apis/distributedtask/deploymentgroups?name={2}&api-version={3}".format(config['VSTSUrl'], quote(config['TeamProject']), quote(config['DeploymentGroup']), Constants.projectAPIVersion)
    
    handler_utility.log("Get deployment group url - {0}".format(get_deployment_group_url))
    response = Util.make_http_request(get_deployment_group_url, 'GET', None, None, config['PATToken'])

    if(response.status != Constants.HTTP_OK):
      if(response.status == Constants.HTTP_FOUND):
        specific_error_message = invalid_pat_error_message
      elif(response.status == Constants.HTTP_UNAUTHORIZED):
        specific_error_message = invalid_pat_error_message
      elif(response.status == Constants.HTTP_FORBIDDEN):
        specific_error_message = "Please ensure that the user has 'View project-level information' permissions on the project '{0}'.".format(config['TeamProject'])
      elif(response.status == Constants.HTTP_NOTFOUND):
        specific_error_message = "Please make sure that you enter the correct organization name and verify that the project exists in the organization."
      else:
        specific_error_message = unexpected_error_message.format(response.status)
        inputs_validation_error_code = RMExtensionStatus.rm_extension_status['GenericError']
      error_message = error_message_initial_part.format(response.status, specific_error_message)
      
      raise RMExtensionStatus.new_handler_terminating_error(inputs_validation_error_code, error_message)


    deployment_group_data = json.loads(str(response.read(), 'utf-8'))

    if(('value' not in deployment_group_data) or len(deployment_group_data['value']) == 0):
      specific_error_message = "Please make sure that the deployment group {0} exists in the project {1}, and the user has 'Manage' permissions on the deployment group.".format(config['DeploymentGroup'], config['TeamProject'])
      raise RMExtensionStatus.new_handler_terminating_error(inputs_validation_error_code, error_message_initial_part.format(response.status, specific_error_message))

    deployment_group_id = deployment_group_data['value'][0]['id']
    handler_utility.log("Validated that the deployment group {0} exists".format(config['DeploymentGroup']))
    
    headers = {}
    headers['Content-Type'] = 'application/json'
    body = "{'name': '" + config['DeploymentGroup'] + "'}"
    patch_deployment_group_url = "{0}/{1}/_apis/distributedtask/deploymentgroups/{2}?api-version={3}".format(config['VSTSUrl'], quote(config['TeamProject']), deployment_group_id, Constants.projectAPIVersion) 
    
    handler_utility.log("Patch deployment group url - {0}".format(patch_deployment_group_url))
    response = Util.make_http_request(patch_deployment_group_url, 'PATCH', body, headers, config['PATToken'])

    if(response.status != Constants.HTTP_OK):
      if(response.status == Constants.HTTP_FORBIDDEN):
        specific_error_message = "Please ensure that the user has 'Manage' permissions on the deployment group {0}".format(config['DeploymentGroup'])
      else:
        specific_error_message = unexpected_error_message.format(str(response.status))
        inputs_validation_error_code = RMExtensionStatus.rm_extension_status['GenericError']

      raise RMExtensionStatus.new_handler_terminating_error(inputs_validation_error_code, error_message_initial_part.format(response.status, response.reason) + specific_error_message)
      

    handler_utility.log("Validated that the user has 'Manage' permissions on the deployment group '{0}'".format(config['DeploymentGroup']))
    handler_utility.log("Done validating inputs...")
    handler_utility.add_handler_sub_status(Util.HandlerSubStatus('SuccessfullyValidatedInputs'))

  except Exception as e:
    set_error_status_and_error_exit(e, RMExtensionStatus.rm_extension_status['ValidatingInputs']['operationName'], e.__getattribute__('Code'))

def get_configuration_from_settings():
  try:
    public_settings = handler_utility.get_public_settings()
    if(public_settings == None):
      public_settings = {}
    handler_utility.verify_public_settings_is_dict(public_settings)

    protected_settings = handler_utility.get_protected_settings()
    if(protected_settings == None):
      protected_settings = {}

    #fetching proxy settings, which are common for both deploymentgroup and byos

    proxy_url = ''
    if('https_proxy' in  os.environ):
      proxy_url = os.environ['https_proxy']
    elif('HTTPS_PROXY' in  os.environ):
      proxy_url = os.environ['HTTPS_PROXY']
    elif('http_proxy' in  os.environ):
      proxy_url = os.environ['http_proxy']
    elif('HTTP_PROXY' in  os.environ):
      proxy_url = os.environ['HTTP_PROXY']
    if(proxy_url):
      handler_utility.log('ProxyUrl is present')
      proxy_config['ProxyUrl'] = proxy_url
      
    # If this is a pipelines agent, read the settings and return quickly
    # Note that the pipelines settings come over as camelCase
    if('isPipelinesAgent' in public_settings):
      handler_utility.log("Is Pipelines Agent")

      # read pipelines agent settings
      agentDownloadUrl = public_settings['agentDownloadUrl']
      handler_utility.verify_input_not_null('agentDownloadUrl', agentDownloadUrl)

      agentFolder = public_settings['agentFolder']
      handler_utility.verify_input_not_null('agentFolder', agentFolder)

      enableScriptDownloadUrl = public_settings['enableScriptDownloadUrl']
      handler_utility.verify_input_not_null('enableScriptDownloadUrl', enableScriptDownloadUrl)

      # for testing, first try to get the script parameters from the public settings
      # in production they will be in the protected settings
      if('enableScriptParameters' in public_settings):
        handler_utility.log("using public enableScriptParameters")
        enableScriptParameters = public_settings['enableScriptParameters']
      elif('enableScriptParameters' in protected_settings):
        handler_utility.log("using protected enableScriptParameters")
        enableScriptParameters = protected_settings['enableScriptParameters']

      return {
              'IsPipelinesAgent': 'true',
              'AgentDownloadUrl':agentDownloadUrl,
              'AgentFolder':agentFolder,
              'EnableScriptDownloadUrl':enableScriptDownloadUrl,
              'EnableScriptParameters':enableScriptParameters
            }

    # continue with deployment agent settings
    handler_utility.log("Is Deployment Agent")
    pat_token = ''
    if((protected_settings.__class__.__name__ == 'dict') and 'PATToken' in protected_settings):
      pat_token = protected_settings['PATToken']
    if((pat_token == '') and ('PATToken' in public_settings)):
      pat_token = public_settings['PATToken']

    vsts_account_url = ''
    if('AzureDevOpsOrganizationUrl' in public_settings):
      vsts_account_url = public_settings['AzureDevOpsOrganizationUrl'].strip('/')
    elif('VSTSAccountUrl' in public_settings):
      vsts_account_url = public_settings['VSTSAccountUrl'].strip('/')
    elif('VSTSAccountName' in public_settings):
      vsts_account_url = public_settings['VSTSAccountName'].strip('/')
    handler_utility.verify_input_not_null('AzureDevOpsOrganizationUrl', vsts_account_url)
    vsts_url = vsts_account_url

    vsts_url = parse_account_name(vsts_account_url, pat_token)
    handler_utility.log('Azure DevOps Organization Url : {0}'.format(vsts_url))

    team_project_name = ''
    if('TeamProject' in public_settings):
      team_project_name = public_settings['TeamProject']
    handler_utility.verify_input_not_null('TeamProject', team_project_name)
    handler_utility.log('Team Project : {0}'.format(team_project_name))

    deployment_group_name = ''
    if('DeploymentGroup' in public_settings):
      deployment_group_name = public_settings['DeploymentGroup']
    elif('MachineGroup' in public_settings):
      deployment_group_name = public_settings['MachineGroup']
    handler_utility.verify_input_not_null('DeploymentGroup', deployment_group_name)
    handler_utility.log('Deployment Group : {0}'.format(deployment_group_name))

    agent_name = ''
    if('AgentName' in public_settings):
      agent_name = public_settings['AgentName']
    handler_utility.log('Agent Name : {0}'.format(agent_name))

    tags_input = [] 
    if('Tags' in public_settings):
      tags_input = public_settings['Tags']
    handler_utility.log('Tags : {0}'.format(tags_input))
    tags = format_tags_input(tags_input)

    configure_agent_as_username = ''
    if('UserName' in public_settings):
      configure_agent_as_username = public_settings['UserName']

    handler_utility.log('Done reading config settings from file...')
    handler_utility.add_handler_sub_status(Util.HandlerSubStatus('SuccessfullyReadSettings'))
    return {
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
    set_error_status_and_error_exit(e, RMExtensionStatus.rm_extension_status['ReadingSettings']['operationName'], RMExtensionStatus.rm_extension_status['InputConfigurationError'])

def test_agent_configuration_required(config):
  handler_utility.log('Checking existing agent settings with given configuration settings...')
  agent_reconfiguration_required = ConfigureDeploymentAgent.is_agent_configuration_required(config['VSTSUrl'], config['PATToken'], \
                      config['DeploymentGroup'], config['TeamProject'], config['AgentWorkingFolder'])
  handler_utility.log('Checked existing settings with given settings. agent_reconfiguration_required : {0}'.format(agent_reconfiguration_required))
  return agent_reconfiguration_required

def execute_agent_pre_check(config):
  global configured_agent_exists, agent_configuration_required
  try:
    handler_utility.add_handler_sub_status(Util.HandlerSubStatus('PreCheckingDeploymentAgent'))
    configured_agent_exists = ConfigureDeploymentAgent.is_agent_configured(config['AgentWorkingFolder'])
    if(configured_agent_exists == True):
      agent_configuration_required = test_agent_configuration_required(config)
    handler_utility.add_handler_sub_status(Util.HandlerSubStatus('PreCheckedDeploymentAgent'))
  except Exception as e:
    set_error_status_and_error_exit(e, RMExtensionStatus.rm_extension_status['PreCheckingDeploymentAgent']['operationName'], 3)
  
def get_agent(config):
  try:
    handler_utility.add_handler_sub_status(Util.HandlerSubStatus('DownloadingDeploymentAgent'))
    
    handler_utility.log('Invoking function to download Deployment agent package...')
    DownloadDeploymentAgent.download_deployment_agent(config['VSTSUrl'], config['PATToken'], config['AgentWorkingFolder'])
    handler_utility.log('Agent package downloaded and extracted')

    handler_utility.add_handler_sub_status(Util.HandlerSubStatus('DownloadedDeploymentAgent'))
  except Exception as e:
    set_error_status_and_error_exit(e, RMExtensionStatus.rm_extension_status['DownloadingDeploymentAgent']['operationName'], 5)

def download_agent_if_required(config):
  global configured_agent_exists
  if(configured_agent_exists == False):
    get_agent(config)
  else:
    handler_utility.log('Skipping agent download as agent already exists.')
    handler_utility.add_handler_sub_status(Util.HandlerSubStatus('SkippingDownloadDeploymentAgent'))

def register_agent(config):
  global configured_agent_exists
  try:
    
    handler_utility.add_handler_sub_status(Util.HandlerSubStatus('ConfiguringDeploymentAgent'))
    handler_utility.log('Configuring agent...')
    ConfigureDeploymentAgent.configure_agent(config['VSTSUrl'], config['PATToken'], config['TeamProject'], \
      config['DeploymentGroup'], config['ConfigureAgentAsUserName'], config['AgentName'], config['AgentWorkingFolder'])
    handler_utility.log('Agent configured successfully')
    
    handler_utility.add_handler_sub_status(Util.HandlerSubStatus('ConfiguredDeploymentAgent'))
  except Exception as e:
    set_error_status_and_error_exit(e, RMExtensionStatus.rm_extension_status['ConfiguringDeploymentAgent']['operationName'], 6)

def remove_existing_agent(config):
  try:
    handler_utility.log('Agent removal started')
    try:
      ConfigureDeploymentAgent.remove_existing_agent(config['AgentWorkingFolder'])
      
      handler_utility.add_handler_sub_status(Util.HandlerSubStatus('RemovedAgent'))
      
      if(os.access(config['AgentWorkingFolder'], os.F_OK)):
        DownloadDeploymentAgent.clean_agent_folder(config['AgentWorkingFolder'])
      else:
        raise Exception('Cannot cleanup the agent working folder. Access not granted')
    
    except Exception as e:
      handler_utility.log('An unexpected error occured: {0}'.format(str(e)))
      raise e
    ConfigureDeploymentAgent.setting_params = {}
  except Exception as e:
    set_error_status_and_error_exit(e, RMExtensionStatus.rm_extension_status['Uninstalling']['operationName'], 7)

def remove_existing_agent_if_required(config):
  global configured_agent_exists, agent_configuration_required
  if((configured_agent_exists == True) and (agent_configuration_required == True)):
    handler_utility.log('Removing existing configured agent')
    remove_existing_agent(config)
    #Execution has reached till here means that either the agent was removed successfully.
    configured_agent_exists = False

def configure_agent_if_required(config):
  if(agent_configuration_required):
    install_dependencies(config)
    register_agent(config)
  else:
    handler_utility.log('Agent is already configured with given set of parameters. Skipping agent configuration.')
    handler_utility.add_handler_sub_status(Util.HandlerSubStatus('SkippingAgentConfiguration'))

def add_agent_tags(config):

  try:
    handler_utility.add_handler_sub_status(Util.HandlerSubStatus('AddingAgentTags'))

    if(config['Tags'] !=None and len(config['Tags']) > 0):
      handler_utility.log('Adding tags to configured agent - {0}'.format(str(config['Tags'])))
      tags_string = json.dumps(config['Tags'], ensure_ascii = False)
      ConfigureDeploymentAgent.add_agent_tags(config['VSTSUrl'], config['TeamProject'], \
      config['PATToken'], config['AgentWorkingFolder'], tags_string)
      
      handler_utility.add_handler_sub_status(Util.HandlerSubStatus('AgentTagsAdded'))
    else:
      handler_utility.log('No tags provided for agent')
  except Exception as e:
      set_error_status_and_error_exit(e, RMExtensionStatus.rm_extension_status['AddingAgentTags']['operationName'], 8)

def test_extension_settings_are_same_as_disabled_version():
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
        handler_utility.log('Disabled version and new extension version settings are same.')
        return True
      else:
        handler_utility.log('Disabled version and new extension version settings are not same.')
        handler_utility.log('Disabled version settings: {0}'.format(old_extension_public_settings))
        handler_utility.log('New version settings: {0}'.format(extension_public_settings))
    else:
      handler_utility.log('Disabled version settings file does not exist in the agent directory. Will continue with enable.')
    return False
  except Exception as e:
    handler_utility.log('Disabled settings check failed. Error: {0}'.format(str(e)))
    return False

def enable_pipelines_agent(config):
  try:

    handler_utility.log('Enable Pipelines Agent')

    # verify we have the enable script parameters here.
    handler_utility.verify_input_not_null('enableScriptParameters', config["EnableScriptParameters"])

    handler_utility.add_handler_sub_status(Util.HandlerSubStatus('DownloadPipelinesAgent'))
    agentFolder = config["AgentFolder"]
    handler_utility.log(agentFolder)

    if(not os.path.isdir(agentFolder)):
      handler_utility.log('Agent folder does not exist. Creating it.')
      os.makedirs(agentFolder, 0o777)

    # download the agent tar file
    handler_utility.add_handler_sub_status(Util.HandlerSubStatus('DownloadPipelinesZip'))
    handler_utility.log('Download Pipelines Zip')
    downloadUrl = config["AgentDownloadUrl"]
    handler_utility.log(downloadUrl)
    filename = os.path.basename(downloadUrl)
    agentFile = os.path.join(agentFolder, filename)
    for attempt in range(1,MAX_RETRIES+1):
      # retry up to 3 times
      try:
        Util.url_retrieve(downloadUrl, agentFile)
        break
      except Exception as e:
        handler_utility.log("Attempt {0} to download the agent failed".format(attempt))
        handler_utility.log(str(e))
        if attempt == MAX_RETRIES:
          handler_utility.log("Max retries attempt reached")
          set_error_status_and_error_exit(e, RMExtensionStatus.rm_extension_status['DownloadPipelinesAgentError']['operationName'], str(e))

    # download the enable script
    handler_utility.add_handler_sub_status(Util.HandlerSubStatus('DownloadPipelinesScript'))
    handler_utility.log('Download Pipelines Script')
    downloadUrl = config["EnableScriptDownloadUrl"]
    handler_utility.log(downloadUrl)
    filename = os.path.basename(downloadUrl)
    enableFile = os.path.join(agentFolder, filename)
    for attempt in range(1,MAX_RETRIES+1):
      # retry up to 3 times
      try: 
        Util.url_retrieve(downloadUrl, enableFile)
        break
      except Exception as e:
        handler_utility.log("Attempt {0} to download the pipeline script failed".format(attempt))
        handler_utility.log(str(e))
        if attempt == MAX_RETRIES:
          handler_utility.log("Max retries attempt reached")
          set_error_status_and_error_exit(e, RMExtensionStatus.rm_extension_status['DownloadPipelinesAgentError']['operationName'], str(e))


  except Exception as e:
    handler_utility.log(str(e))
    set_error_status_and_error_exit(e, RMExtensionStatus.rm_extension_status['DownloadPipelinesAgentError']['operationName'], str(e))
    return

  try:
    # grant executable access to the script    
    os.chmod(enableFile, 0o777)

    # run the enable script
    handler_utility.add_handler_sub_status(Util.HandlerSubStatus('EnablePipelinesAgent'))
    handler_utility.log('Run Pipelines Script')
    handler_utility.log(enableFile)
    enableParameters = config["EnableScriptParameters"]

    # run the script and wait for it to complete
    handler_utility.log("running script")
    env = {
        **os.environ
    }
    if ('ProxyUrl' in proxy_config):
      proxy_url = proxy_config['ProxyUrl']
      env["http_proxy"] = proxy_url
      env["https_proxy"] = proxy_url
    argList =  ['/bin/bash', enableFile] + shlex.split(enableParameters)
    enableProcess = subprocess.Popen(argList, stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=env)
    (output, error) = enableProcess.communicate()
    handler_utility.log(output.decode("utf-8"))
    handler_utility.log(error.decode("utf-8"))
    if enableProcess.returncode != 0:
      raise Exception("Pipeline script execution failed with exit code {0}".format(enableProcess.returncode))

  except Exception as e:
    handler_utility.log(str(e))
    set_error_status_and_error_exit(e, RMExtensionStatus.rm_extension_status['EnablePipelinesAgentError']['operationName'], str(e))
    return

  handler_utility.add_handler_sub_status(Util.HandlerSubStatus('EnablePipelinesAgentSuccess'))
  handler_utility.set_handler_status(Util.HandlerStatus('Enabled', 'success'))
  handler_utility.log('Pipelines Agent is enabled.')

def enable():
  compare_sequence_number()
  handler_utility.set_handler_status(Util.HandlerStatus('Installing'))
  pre_validation_checks()
  config = get_configuration_from_settings()
  if(config.get('IsPipelinesAgent') != None):
    enable_pipelines_agent(config)
    return

  settings_are_same = test_extension_settings_are_same_as_disabled_version()
  if(settings_are_same):
    handler_utility.log("Skipping extension enable.")
    handler_utility.add_handler_sub_status(Util.HandlerSubStatus('SkippingEnableSameSettingsAsDisabledVersion'))
  else:
    validate_inputs(config)
    ConfigureDeploymentAgent.set_logger(handler_utility.log)
    DownloadDeploymentAgent.set_logger(handler_utility.log)
    execute_agent_pre_check(config)
    remove_existing_agent_if_required(config)
    download_agent_if_required(config)
    configure_agent_if_required(config)
    handler_utility.set_handler_status(Util.HandlerStatus('Installed'))
    add_agent_tags(config)
    handler_utility.log('Extension is enabled.')
  
  handler_utility.set_handler_status(Util.HandlerStatus('Enabled', 'success'))

  set_last_sequence_number()
  handler_utility.log('Removing disable markup file..')
  remove_extension_disabled_markup()

def disable():
  ConfigureDeploymentAgent.set_logger(handler_utility.log)
  config = get_configuration_from_settings()

  if(config.get('IsPipelinesAgent') != None):
    return

  handler_utility.log('Disable command is no-op for agent')
  handler_utility.log('Disabling extension handler. Creating a markup file..')
  set_extension_disabled_markup()
  
  handler_utility.add_handler_sub_status(Util.HandlerSubStatus('Disabled'))
  
  handler_utility.set_handler_status(Util.HandlerStatus('Disabled', 'success'))

def uninstall():
  config = get_configuration_from_settings()

  if(config.get('IsPipelinesAgent') != None):
    return

  global configured_agent_exists
  configured_agent_exists = ConfigureDeploymentAgent.is_agent_configured(Constants.agent_working_folder)
  extension_update_file = '{0}/{1}'.format(Constants.agent_working_folder, Constants.update_file_name)
  is_udpate_scenario = os.path.isfile(extension_update_file)
  if(not(is_udpate_scenario)):  
    if(configured_agent_exists == True):
      config = {
             'AgentWorkingFolder':Constants.agent_working_folder,
          }
      remove_existing_agent(config)
  else:
    handler_utility.log('Extension update scenario. Deleting the file {0}/{1}'.format(Constants.agent_working_folder, Constants.update_file_name))
    os.remove(extension_update_file)
  
  handler_utility.set_handler_status(Util.HandlerStatus('Uninstalling', 'success'))

def update():
  config = get_configuration_from_settings()

  if(config.get('IsPipelinesAgent') != None):
    return

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

      if(input_operation == Constants.ENABLE):
        enable()
      elif(input_operation == Constants.DISABLE):
        disable()
      elif(input_operation == Constants.UNINSTALL):
        uninstall()
      elif(input_operation == Constants.UPDATE):
        update()

      exit_with_code(0)
    except Exception as e:
      set_error_status_and_error_exit(e, 'main', 9)

if(__name__ == '__main__'):
  main()

