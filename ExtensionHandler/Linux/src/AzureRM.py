#! /usr/bin/python

import sys
from Utils.WAAgentUtil import waagent
import Utils.HandlerUtil as Util
import Utils.RMExtensionStatus as RMExtensionStatus
import os
import subprocess
import platform
import Constants
import DownloadDeploymentAgent
import ConfigureDeploymentAgent
import json
import time
from distutils.version import LooseVersion

configured_agent_exists = False
agent_configuration_required = True
config = {}
root_dir = ''
markup_file_format = '{0}/EXTENSIONDISABLED'
collection = ''

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
  global markup_file_format, root_dir
  markup_file = markup_file_format.format(root_dir)
  handler_utility.log('Creating disabled markup file {0}'.format(markup_file))
  try:
    with open(markup_file, 'w') as f:
      f.write('')
      f.close()
  except Exception as e:
    pass

def test_extension_disabled_markup():
  global markup_file_format, root_dir
  markup_file = markup_file_format.format(root_dir)
  handler_utility.log('Testing whether disabled markup file exists: ' + markup_file)
  if(os.path.isfile(markup_file)):
    return True
  else:
    return False

def remove_extension_disabled_markup():
  global markup_file_format, root_dir
  markup_file = markup_file_format.format(root_dir)
  handler_utility.log('Deleting disabled markup file if it exists' + markup_file)
  if(os.path.isfile(markup_file)):
    os.remove(markup_file)

def exit_with_code_zero():
  sys.exit(0)

def exit_with_non_zero_code(code):
  sys.exit(code)

def set_error_status_and_error_exit(e, operation_name, operation, code):
  handler_utility.set_handler_error_status(e, operation_name, operation)
  # Log to command execution log file.
  handler_utility._set_log_file_to_command_execution_log()
  error_message = getattr(e,'message')
  # For unhandled exceptions that we might have missed to catch and specify error message.
  if(len(error_message) > 200):
    error_message = error_message[:200]
  handler_utility.error('Error occured during {0}'.format(operation_name))
  handler_utility.error(error_message)
  exit_with_non_zero_code(code)

def check_python_version():
  version_info = sys.version_info
  version = '{0}.{1}'.format(version_info[0], version_info[1])
  if(LooseVersion(version) < LooseVersion('2.6')):
    code = RMExtensionStatus.rm_extension_status['PythonVersionNotSupported']['Code']
    message = RMExtensionStatus.rm_extension_status['PythonVersionNotSupported']['Message'].format(str(major) + '.' + str(minor))
    raise RMExtensionStatus.new_handler_terminating_error(code, message)

def check_systemd_exists():
  check_systemd_command = 'command -v systemd'
  check_systemd_proc = subprocess.Popen(['/bin/bash', '-c', check_systemd_command], stdout = subprocess.PIPE, stderr = subprocess.PIPE)
  check_systemd_out, check_systemd_err = check_systemd_proc.communicate()
  return_code = check_systemd_proc.returncode
  handler_utility.log('Check systemd process exit code : {0}'.format(return_code))
  handler_utility.log('stdout : {0}'.format(check_systemd_out))
  handler_utility.log('srderr : {0}'.format(check_systemd_err))
  if(return_code == 0):
    handler_utility.log('systemd is installed on the machine.')
  else:
    raise Exception('Could not find systmd on the machine. Error message: {0}'.format(check_systemd_err))

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
      ss_code = RMExtensionStatus.rm_extension_status['SkippedInstallation']['Code']
      sub_status_message = RMExtensionStatus.rm_extension_status['SkippedInstallation']['Message']
      operation_name = RMExtensionStatus.rm_extension_status['SkippedInstallation']['operationName']
      handler_utility.set_handler_status(ss_code = ss_code, sub_status_message = sub_status_message, operation_name = operation_name)
      exit_with_code_zero()
    handler_utility.clear_status_file()
    code = RMExtensionStatus.rm_extension_status['Installing']['Code']
    message = RMExtensionStatus.rm_extension_status['Installing']['Message']
    handler_utility.set_handler_status(operation = operation, code = code, message = message)
    ss_code = RMExtensionStatus.rm_extension_status['Initialized']['Code']
    sub_status_message = RMExtensionStatus.rm_extension_status['Initialized']['Message']
    operation_name = RMExtensionStatus.rm_extension_status['Initialized']['operationName']
    handler_utility.set_handler_status(ss_code = ss_code, sub_status_message = sub_status_message, operation_name = operation_name)
  except Exception as e:
    set_error_status_and_error_exit(e, RMExtensionStatus.rm_extension_status['Initializing']['operationName'], operation, 1)

def get_account_name_prefix(account_name):
  account_name_lower = account_name.lower()
  if(account_name_lower.startswith('http://')):
    return 'http://'
  elif(account_name_lower.startswith('https://')):
    return 'https://'
  return '' 

def parse_account_name(account_name): 
  account_name = account_name.lower()
  base_url = account_name
  virtual_application = ''
  collection = ''
  account_name_prefix = get_account_name_prefix(account_name)
  if(account_name_prefix != ''):
    account_name = account_name[7:]
  account_name = account_name.strip('/')
  account_name_split = filter(lambda x: x!='', account_name.split('/'))
  if(account_name_split[0].endswith('visualstudio.com')):
    base_url = 'https://' + account_name_split[0]
  elif(account_name_prefix != ''):
    Constants.is_on_prem = True
    if(len(account_name_split) >= 2):
      base_url = account_name_prefix + account_name_split[0]
      virtual_application = account_name_split[1]
      collection = 'DefaultCollection'
      if(len(account_name_split) > 2):
        collection = account_name_split[2]
    else:
      code = RMExtensionStatus.rm_extension_status['InvalidAccountName']['Code']
      message = RMExtensionStatus.rm_extension_status['InvalidAccountName']['Message']
      raise RMExtensionStatus.new_handler_terminating_error(code, message)
  return {
         'VSTSUrl':base_url,
         'VirtualApplication':virtual_application,
         'Collection':collection
         }

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
    if(x!='' and x.lower() not in map(lambda x:x.lower(), ret_val)):
      ret_val.append(x)
  return ret_val

def create_agent_working_folder():
  agent_working_folder = '{0}/VSTSAgent'.format('')
  handler_utility.log('Working folder for VSTS agent : {0}'.format(agent_working_folder))
  if(not os.path.isdir(agent_working_folder)):
    handler_utility.log('Working folder does not exist. Creating it...')
    os.makedirs(agent_working_folder, 0700)
  return agent_working_folder

def get_configutation_from_settings(operation):
  try:
    format_string = 'https://{0}.visualstudio.com'
    public_settings = handler_utility.get_public_settings()
    protected_settings = handler_utility.get_protected_settings()
    if(public_settings == None):
      public_settings = {}
    if(protected_settings == None):
      protected_settings = {}
    os_version = handler_utility.get_os_version()
    if(os_version['IsX64'] != True):
      code = RMExtensionStatus.rm_extension_status['ArchitectureNotSupported']['Code']
      RMExtensionStatus.rm_extension_status['ArchitectureNotSupported']['Message']
      raise new_handler_terminating_error(code, message)
    vsts_account_name = public_settings['VSTSAccountName'].strip('/')
    handler_utility.verify_input_not_null('VSTSAccountName', vsts_account_name)
    account_info = parse_account_name(vsts_account_name)
    vsts_url = account_info['VSTSUrl']
    virtual_application = account_info['VirtualApplication']
    collection = account_info['Collection']
    if(get_account_name_prefix(vsts_url) == ''):
      vsts_url = format_string.format(vsts_account_name)
    handler_utility.log('VSTS service URL : {0}'.format(vsts_url))
    pat_token = ''
    if((protected_settings.__class__.__name__ == 'dict') and protected_settings.has_key('PATToken')):
      pat_token = protected_settings['PATToken']
    if((pat_token == '') and (public_settings.has_key('PATToken'))):
      pat_token = public_settings['PATToken']
    team_project_name = public_settings['TeamProject']
    handler_utility.verify_input_not_null('TeamProject', team_project_name)
    handler_utility.log('Team Project : {0}'.format(team_project_name))
    if(public_settings.has_key('DeploymentGroup')):
      deployment_group_name = public_settings['DeploymentGroup']
    elif(public_settings.has_key('MachineGroup')):
      deployment_group_name = public_settings['MachineGroup']
    handler_utility.verify_input_not_null('DeploymentGroup', deployment_group_name)
    handler_utility.log('Deployment Group : {0}'.format(deployment_group_name))
    agent_name = public_settings['AgentName']
    handler_utility.log('Agent Name : {0}'.format(agent_name))
    tags_input = [] 
    if(public_settings.has_key('Tags')):
      tags_input = public_settings['Tags']
    handler_utility.log('Tags : {0}'.format(tags_input))
    tags = format_tags_input(tags_input)
    agent_working_folder = create_agent_working_folder()
    handler_utility.log('Done reading config settings from file...')
    ss_code = RMExtensionStatus.rm_extension_status['SuccessfullyReadSettings']['Code']
    sub_status_message = RMExtensionStatus.rm_extension_status['SuccessfullyReadSettings']['Message']
    operation_name = RMExtensionStatus.rm_extension_status['SuccessfullyReadSettings']['operationName']
    handler_utility.set_handler_status(ss_code = ss_code, sub_status_message = sub_status_message, operation_name = operation_name)
    ret_val = {
             'VSTSUrl':[vsts_url, virtual_application, collection],
             'PATToken':pat_token, 
             'TeamProject':team_project_name, 
             'DeploymentGroup':deployment_group_name, 
             'AgentName':agent_name, 
             'Tags' : tags,
             'AgentWorkingFolder':agent_working_folder
          }
    return ret_val
  except Exception as e:
    set_error_status_and_error_exit(e, RMExtensionStatus.rm_extension_status['ReadingSettings']['operationName'], operation, 2)

def test_configured_agent_exists(operation):
  global configured_agent_exists, config
  try:
    ss_code = RMExtensionStatus.rm_extension_status['PreCheckingDeploymentAgent']['Code']
    sub_status_message = RMExtensionStatus.rm_extension_status['PreCheckingDeploymentAgent']['Message']
    operation_name = RMExtensionStatus.rm_extension_status['PreCheckingDeploymentAgent']['operationName']
    handler_utility.set_handler_status(ss_code = ss_code, sub_status_message = sub_status_message, operation_name = operation_name)
    handler_utility.log('Invoking function to pre-check agent configuration...')
    agent_exists = ConfigureDeploymentAgent.test_configured_agent_exists_internal(config['AgentWorkingFolder'], handler_utility.log)
    handler_utility.log('Done pre-checking agent configuration')
    ss_code = RMExtensionStatus.rm_extension_status['PreCheckedDeploymentAgent']['Code']
    sub_status_message = RMExtensionStatus.rm_extension_status['PreCheckedDeploymentAgent']['Message']
    operation_name = RMExtensionStatus.rm_extension_status['PreCheckedDeploymentAgent']['operationName']
    handler_utility.set_handler_status(ss_code = ss_code, sub_status_message = sub_status_message, operation_name = operation_name)
    return agent_exists
  except Exception as e:
    set_error_status_and_error_exit(e, RMExtensionStatus.rm_extension_status['PreCheckingDeploymentAgent']['operationName'], operation, 3)

def test_agent_configuration_required():
  global config
  try:
    ss_code = RMExtensionStatus.rm_extension_status['CheckingAgentReConfigurationRequired']['Code']
    sub_status_message = RMExtensionStatus.rm_extension_status['CheckingAgentReConfigurationRequired']['Message']
    operation_name = RMExtensionStatus.rm_extension_status['CheckingAgentReConfigurationRequired']['operationName']
    handler_utility.set_handler_status(ss_code = ss_code, sub_status_message = sub_status_message, operation_name = operation_name)
    handler_utility.log('Invoking script to check existing agent settings with given configuration settings...')
    config_required = ConfigureDeploymentAgent.test_agent_configuration_required_internal(config['VSTSUrl'], config['PATToken'], \
                      config['DeploymentGroup'], config['TeamProject'], config['AgentWorkingFolder'], handler_utility.log)
    ss_code = RMExtensionStatus.rm_extension_status['AgentReConfigurationRequiredChecked']['Code']
    sub_status_message = RMExtensionStatus.rm_extension_status['AgentReConfigurationRequiredChecked']['Message']
    operation_name = RMExtensionStatus.rm_extension_status['AgentReConfigurationRequiredChecked']['operationName']
    handler_utility.set_handler_status(ss_code = ss_code, sub_status_message = sub_status_message, operation_name = operation_name)
    handler_utility.log('Done pre-checking for agent re-configuration, AgentReconfigurationRequired : {0}'.format(config_required))
    return config_required
  except Exception as e:
    set_error_status_and_error_exit(e, RMExtensionStatus.rm_extension_status['CheckingAgentReConfigurationRequired']['operationName'], 'Enable', 4)

def execute_agent_pre_check():
  global config, configured_agent_exists, agent_configuration_required
  configured_agent_exists = test_configured_agent_exists('Enable')
  if(configured_agent_exists == True):
    agent_configuration_required = test_agent_configuration_required()
  
def get_agent():
  global config
  try:
    ss_code = RMExtensionStatus.rm_extension_status['DownloadingDeploymentAgent']['Code']
    sub_status_message = RMExtensionStatus.rm_extension_status['DownloadingDeploymentAgent']['Message']
    operation_name = RMExtensionStatus.rm_extension_status['DownloadingDeploymentAgent']['operationName']
    handler_utility.set_handler_status(ss_code = ss_code, sub_status_message = sub_status_message, operation_name = operation_name)
    handler_utility.log('Invoking function to download Deployment agent package...')
    DownloadDeploymentAgent.download_deployment_agent(config['VSTSUrl'], '', config['PATToken'], \
    config['AgentWorkingFolder'], handler_utility.log)
    handler_utility.log('Done downloading Deployment agent package...')
    ss_code = RMExtensionStatus.rm_extension_status['DownloadedDeploymentAgent']['Code']
    sub_status_message = RMExtensionStatus.rm_extension_status['DownloadedDeploymentAgent']['Message']
    operation_name = RMExtensionStatus.rm_extension_status['DownloadedDeploymentAgent']['operationName']
    handler_utility.set_handler_status(ss_code = ss_code, sub_status_message = sub_status_message, operation_name = operation_name)
  except Exception as e:
    set_error_status_and_error_exit(e, RMExtensionStatus.rm_extension_status['DownloadingDeploymentAgent']['operationName'], 'Enable', 5)

def download_agent_if_required():
  global configured_agent_exists
  if(configured_agent_exists == False):
    get_agent()
  else:
    handler_utility.log('Skipping agent download as agent already exists.')
    ss_code = RMExtensionStatus.rm_extension_status['SkippingDownloadDeploymentAgent']['Code']
    sub_status_message = RMExtensionStatus.rm_extension_status['SkippingDownloadDeploymentAgent']['Message']
    operation_name = RMExtensionStatus.rm_extension_status['SkippingDownloadDeploymentAgent']['operationName']
    handler_utility.set_handler_status(ss_code = ss_code, sub_status_message = sub_status_message, operation_name = operation_name)
  

def register_agent():
  global config, configured_agent_exists
  try:
    ss_code = RMExtensionStatus.rm_extension_status['ConfiguringDeploymentAgent']['Code']
    sub_status_message = RMExtensionStatus.rm_extension_status['ConfiguringDeploymentAgent']['Message']
    operation_name = RMExtensionStatus.rm_extension_status['ConfiguringDeploymentAgent']['operationName']
    handler_utility.set_handler_status(ss_code = ss_code, sub_status_message = sub_status_message, operation_name = operation_name)
    handler_utility.log('Configuring Deployment agent...')
    ConfigureDeploymentAgent.configure_agent(config['VSTSUrl'], config['PATToken'], config['TeamProject'], \
    config['DeploymentGroup'], config['AgentName'], config['AgentWorkingFolder'], configured_agent_exists, handler_utility.log)
    handler_utility.log('Done configuring Deployment agent')
    ss_code = RMExtensionStatus.rm_extension_status['ConfiguredDeploymentAgent']['Code']
    sub_status_message = RMExtensionStatus.rm_extension_status['ConfiguredDeploymentAgent']['Message']
    operation_name = RMExtensionStatus.rm_extension_status['ConfiguredDeploymentAgent']['operationName']
    handler_utility.set_handler_status(ss_code = ss_code, sub_status_message = sub_status_message, operation_name = operation_name)
    code = RMExtensionStatus.rm_extension_status['Installed']['Code']
    message = RMExtensionStatus.rm_extension_status['Installed']['Message']
    handler_utility.set_handler_status(operation = 'Enable', code = code, message = message)
  except Exception as e:
    set_error_status_and_error_exit(e, RMExtensionStatus.rm_extension_status['ConfiguringDeploymentAgent']['operationName'], 'Enable', 6)

def remove_existing_agent(operation):
  global config
  try:
    handler_utility.log('Agent removal started')
    try:
      ConfigureDeploymentAgent.remove_existing_agent_internal(config['PATToken'], config['AgentWorkingFolder'], handler_utility.log)
      ss_code = RMExtensionStatus.rm_extension_status['RemovedAgent']['Code']
      sub_status_message = RMExtensionStatus.rm_extension_status['RemovedAgent']['Message']
      operation_name = RMExtensionStatus.rm_extension_status['RemovedAgent']['operationName']
      handler_utility.set_handler_status(ss_code = ss_code, sub_status_message = sub_status_message, operation_name = operation_name)
    except Exception as e:
      if(('Reason' in dir(e) and getattr(e, 'Reason') == 'UnConfigFailed') and (os.access(config['AgentWorkingFolder'], os.F_OK))):
        Util.include_warning_status = True
        cur_time = '%.6f'%(time.time())
        old_agent_folder_name = config['AgentWorkingFolder'] + cur_time
        handler_utility.log('Failed to unconfigure the VSTS agent. Renaming the agent directory to {0}.'.format(old_agent_folder_name))
        agent_name = ConfigureDeploymentAgent.get_agent_setting(config['AgentWorkingFolder'], 'agentName')
        handler_utility.log('Please delete the agent {0} manually from the deployment group.'.format(agent_name))
        rename_agent_folder_proc = subprocess.Popen('mv {0} {1}'.format(config['AgentWorkingFolder'], old_agent_folder_name).split(' '), stdout = subprocess.PIPE, stderr = subprocess.PIPE)
        std_out, std_err = rename_agent_folder_proc.communicate()
        return_code = rename_agent_folder_proc.returncode
        handler_utility.log('Renaming agent directory process exit code : {0}'.format(return_code))
        handler_utility.log('stdout : {0}'.format(std_out))
        handler_utility.log('srderr : {0}'.format(std_err))
        if(not (return_code == 0)):
          raise Exception('Renaming of agent directory failed with error : {0}'.format(std_err))
        create_agent_working_folder()
        ss_code = RMExtensionStatus.rm_extension_status['UnConfiguringDeploymentAgentFailed']['Code']
        sub_status_message = RMExtensionStatus.rm_extension_status['UnConfiguringDeploymentAgentFailed']['Message'].format(agent_name)
        operation_name = RMExtensionStatus.rm_extension_status['UnConfiguringDeploymentAgentFailed']['operationName']
        handler_utility.set_handler_status(ss_code = ss_code, sub_status = 'warning', sub_status_message = sub_status_message, operation_name = operation_name)
      else:
        raise e
    ConfigureDeploymentAgent.setting_params = {}
  except Exception as e:
    set_error_status_and_error_exit(e, RMExtensionStatus.rm_extension_status['Uninstalling']['operationName'], operation, 7)

def remove_existing_agent_if_required():
  global configured_agent_exists, agent_configuration_required, config
  if((configured_agent_exists == True) and (agent_configuration_required == True)):
    handler_utility.log('Remove existing configured agent')
    remove_existing_agent('Enable')
    #Execution has reached till here means that either the agent was removed successfully, or we renamed the agent folder successfully. 
    configured_agent_exists = False

def configure_agent_if_required():
  if(agent_configuration_required):
    register_agent()
  else:
    ss_code = RMExtensionStatus.rm_extension_status['SkippingAgentConfiguration']['Code']
    sub_status_message = RMExtensionStatus.rm_extension_status['SkippingAgentConfiguration']['Message']
    operation_name = RMExtensionStatus.rm_extension_status['SkippingAgentConfiguration']['operationName']
    handler_utility.set_handler_status(ss_code = ss_code, sub_status_message = sub_status_message, operation_name = operation_name)
    code = RMExtensionStatus.rm_extension_status['SkippingAgentConfiguration']['Code']
    message = RMExtensionStatus.rm_extension_status['SkippingAgentConfiguration']['Message']
    handler_utility.set_handler_status(operation = 'Enable', code = code, message = message) 

def add_agent_tags():
  ss_code = RMExtensionStatus.rm_extension_status['AddingAgentTags']['Code']
  sub_status_message = RMExtensionStatus.rm_extension_status['AddingAgentTags']['Message']
  operation_name = RMExtensionStatus.rm_extension_status['AddingAgentTags']['operationName']
  handler_utility.set_handler_status(ss_code = ss_code, sub_status_message = sub_status_message, operation_name = operation_name)
  if(config['Tags'] !=None and len(config['Tags']) > 0):
    handler_utility.log('Adding tags to configured agent - {0}'.format(str(config['Tags'])))
    try:
      tags_string = json.dumps(config['Tags'], ensure_ascii = False)
      ConfigureDeploymentAgent.add_agent_tags_internal(config['VSTSUrl'], config['TeamProject'], \
      config['PATToken'], config['AgentWorkingFolder'], tags_string, handler_utility.log)
      ss_code = RMExtensionStatus.rm_extension_status['AgentTagsAdded']['Code']
      sub_status_message = RMExtensionStatus.rm_extension_status['AgentTagsAdded']['Message']
      operation_name = RMExtensionStatus.rm_extension_status['AgentTagsAdded']['operationName']
      handler_utility.set_handler_status(ss_code = ss_code, sub_status_message = sub_status_message, operation_name = operation_name)
      code = RMExtensionStatus.rm_extension_status['AgentTagsAdded']['Code']
      message = RMExtensionStatus.rm_extension_status['AgentTagsAdded']['Message']
      handler_utility.set_handler_status(operation = 'Enable', code = code, message = message)
    except Exception as e:
      set_error_status_and_error_exit(e, RMExtensionStatus.rm_extension_status['AgentTagsAdded']['operationName'], 'Enable', 8)
  else:
    handler_utility.log('No tags provided for agent')

def enable():
  global configured_agent_exists, agent_configuration_required, config
  input_operation = 'Enable'
  start_rm_extension_handler(input_operation)
  config = get_configutation_from_settings(input_operation)
  execute_agent_pre_check()
  remove_existing_agent_if_required()
  download_agent_if_required()
  install_dependencies()
  configure_agent_if_required()
  add_agent_tags()
  set_last_sequence_number()
  handler_utility.log('Extension is enabled. Removing any disable markup file..')
  code = RMExtensionStatus.rm_extension_status['Enabled']['Code']
  message = RMExtensionStatus.rm_extension_status['Enabled']['Message']
  handler_utility.set_handler_status(operation = 'Enable', code = code, status = 'success', message = message)
  remove_extension_disabled_markup()

def disable():
  working_folder = '{0}/VSTSAgent'.format('')
  agent_exists = ConfigureDeploymentAgent.test_configured_agent_exists_internal(working_folder, handler_utility.log)
  handler_utility.log('Disable command is no-op for agent')
  handler_utility.log('Creating a markup file...')
  set_extension_disabled_markup()
  ss_code = RMExtensionStatus.rm_extension_status['Disabled']['Code']
  sub_status_message = RMExtensionStatus.rm_extension_status['Disabled']['Message']
  operation_name = RMExtensionStatus.rm_extension_status['Disabled']['operationName']
  handler_utility.set_handler_status(ss_code = ss_code, sub_status_message = sub_status_message, operation_name = operation_name)
  code = RMExtensionStatus.rm_extension_status['Disabled']['Code']
  message = RMExtensionStatus.rm_extension_status['Disabled']['Message']
  handler_utility.set_handler_status(operation = 'Disable', code = code, status = 'success', message = message)

def uninstall():
  global configured_agent_exists, config
  operation = 'Uninstall'
  config = get_configutation_from_settings(operation)
  configured_agent_exists = test_configured_agent_exists(operation)
  config_path = ConfigureDeploymentAgent.get_agent_listener_path(config['AgentWorkingFolder'])
  if(configured_agent_exists == True):
    remove_existing_agent(operation)
  code = RMExtensionStatus.rm_extension_status['Uninstalling']['Code']
  message = RMExtensionStatus.rm_extension_status['Uninstalling']['Message']
  handler_utility.set_handler_status(operation = operation, code = code, status = 'success', message = message)

def main():
  waagent.LoggerInit('/var/log/waagent.log','/dev/stdout')
  waagent.Log('VSTS deployment group extension handler started.')
  if(len(sys.argv) == 2):
    global handler_utility
    handler_utility = Util.HandlerUtility(waagent.Log, waagent.Error)
    operation = sys.argv[1]
    handler_utility.do_parse_context(operation)
    try:
      check_python_version()
      check_systemd_exists()
      global root_dir
      root_dir = os.getcwd()
      if(sys.argv[1] == '-enable'):
	      enable()
      elif(sys.argv[1] == '-disable'):
	      disable()
      elif(sys.argv[1] == '-uninstall'):
	      uninstall()
      exit_with_code_zero()
    except Exception as e:
      set_error_status_and_error_exit(e, 'main', operation, 9)

if(__name__ == '__main__'):
  main()

