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

configured_agent_exists = False
agent_configuration_required = True
config = {}
root_dir = ''
markup_file_format = '{0}/EXTENSIONDISABLED'
is_on_prem = False
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
      return contents
      f.close()
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

def check_python_version():
  version_info = sys.version_info
  major = version_info[0]
  minor = version_info[1]
  if(major < 2 or (major == 2 and minor < 6)):
    code = RMExtensionStatus.rm_extension_status['PythonVersionNotSupported']['Code']
    message = RMExtensionStatus.rm_extension_status['PythonVersionNotSupported']['Message'].format(str(major) + '.' + str(minor))
    raise RMExtensionStatus.new_handler_terminating_error(code, message)

def install_dependencies():
  install_command = []
  linux_version_valid = False
  linux_distr = platform.linux_distribution()
  distr_name = linux_distr[0]
  version = linux_distr[1]
  if(distr_name == Constants.red_hat_distr_name):
    if(version == '7.2'):
      linux_version_valid = True
      install_command += ['/bin/yum', '-yq', 'install', 'libunwind.x86_64', 'icu']
  elif(distr_name == Constants.ubuntu_distr_name):
    if(version == '16.04'):
      linux_version_valid = True
      update_package_list_command = ['/usr/bin/apt-get', 'update', '-yq']
      proc = subprocess.Popen(update_package_list_command, stdout = subprocess.PIPE, stderr = subprocess.PIPE)
      update_out, update_err = proc.communicate()
      install_command += ['/usr/bin/apt-get', 'install', '-yq', 'libunwind8', 'libcurl3']
  if(linux_version_valid == False):
    code = RMExtensionStatus.rm_extension_status['LinuxDistributionNotSupported']['Code']
    message = RMExtensionStatus.rm_extension_status['LinuxDistributionNotSupported']['Message'].format(distr_name, version)
    raise RMExtensionStatus.new_handler_terminating_error(code, message)
  proc = subprocess.Popen(install_command, stdout = subprocess.PIPE, stderr = subprocess.PIPE)
  install_out, install_err = proc.communicate()


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
    handler_utility.set_handler_status(code = code, message = message)
    ss_code = RMExtensionStatus.rm_extension_status['Initialized']['Code']
    sub_status_message = RMExtensionStatus.rm_extension_status['Initialized']['Message']
    operation_name = RMExtensionStatus.rm_extension_status['Initialized']['operationName']
    handler_utility.set_handler_status(ss_code = ss_code, sub_status_message = sub_status_message, operation_name = operation_name)
  except Exception as e:
    handler_utility.set_handler_error_status(e, RMExtensionStatus.rm_extension_status['Initializing']['operationName'])
    exit_with_code_zero()

def get_platform_value():
  info = platform.linux_distribution()
  os_distr_name = info[0]
  if(os_distr_name == Constants.red_hat_distr_name):
    os_distr_name = 'rhel'
  elif(os_distr_name == Constants.ubuntu_distr_name):
    os_distr_name = 'ubuntu'
  version_no = info[1].split('.')[0]
  sub_version = info[1].split('.')[1]
  platform_value = Constants.platform_format.format(os_distr_name, version_no, sub_version, 'x64')
  return platform_value

def check_account_name_prefix(account_name):
  global prefix
  prefix_1 = 'http://'
  prefix_2 = 'https://'
  account_name_lower = account_name.lower()
  ans = (account_name_lower.startswith(prefix_1) or account_name_lower.startswith(prefix_2))
  if(account_name_lower.startswith(prefix_1)):
    prefix = prefix_1
  if(account_name_lower.startswith(prefix_2)):
    prefix = prefix_2
  return ans 

def check_account_name_suffix(account_name):
  suffix_1 = 'vsallin.net'
  suffix_2 = 'tfsallin.net'
  suffix_3 = 'visualstudio.com'
  account_name_lower = account_name.lower()
  ans = (account_name_lower.endswith(suffix_1) or account_name_lower.endswith(suffix_2) or account_name_lower.endswith(suffix_3))
  return ans

def modify_paths(account_name_split):
  Constants.package_data_address_format = '/' + account_name_split['VirtualApplication'] + Constants.package_data_address_format
  Constants.machine_group_address_format = '/' + account_name_split['VirtualApplication'] + '/' + account_name_split['Collection'] + Constants.machine_group_address_format
  Constants.machines_address_format = '/' + account_name_split['VirtualApplication'] + '/' + account_name_split['Collection'] + Constants.machines_address_format
  Constants.machine_groups_address_format = '/' + account_name_split['VirtualApplication'] + '/' + account_name_split['Collection'] + Constants.machine_groups_address_format


def parse_account_name(account_name): 
  global is_on_prem, prefix
  base_url = ''
  virtual_application = ''
  collection = ''
  if(check_account_name_prefix(account_name)):
    account_name = account_name[7:]
  account_name = account_name.strip('/')
  if(account_name.find('/') > -1):
    is_on_prem = True
    account_name_split = filter(lambda x: x!='', account_name.split('/'))
    if(len(account_name_split) == 3):
      base_url = prefix + account_name_split[0]
      virtual_application = account_name_split[1]
      collection = account_name_split[2]
    elif(len(account_name_split) != 1):
      code = RMExtensionStatus.rm_extension_status['ArgumentError']
      message = 'Account url should either be of format https://<account>.visualstudio.com (for hosted) or of format http(s)://<server>/<application>/<collection>(for on-prem)'
      raise RMExtensionStatus.new_handler_terminating_error(code, message)
    else:
      base_url = prefix + account_name_split[0]
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

def get_configutation_from_settings():
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
    platform_value = get_platform_value()
    handler_utility.log('Platform: {0}'.format(platform_value))
    vsts_account_name = public_settings['VSTSAccountName'].strip('/')
    handler_utility.verify_input_not_null('VSTSAccountName', vsts_account_name)
    account_name_split = parse_account_name(vsts_account_name)
    vsts_url = account_name_split['VSTSUrl']
    virtual_application = account_name_split['VirtualApplication']
    collection = account_name_split['Collection']
    if(check_account_name_prefix(vsts_account_name) and check_account_name_suffix(vsts_account_name)):
      vsts_url = vsts_account_name
    else:
      if(is_on_prem):
        modify_paths(account_name_split)
      else:
        vsts_url = format_string.format(vsts_account_name)
    handler_utility.log('VSTS service URL : {0}'.format(vsts_url))
    pat_token = ''
    if(protected_settings.has_key('PATToken')):
      pat_token = protected_settings['PATToken']
    if(pat_token == ''):
      pat_token = public_settings['PATToken']
      handler_utility.verify_input_not_null('PATToken', pat_token)
    team_project_name = public_settings['TeamProject']
    handler_utility.verify_input_not_null('TeamProject', team_project_name)
    handler_utility.log('Team Project : {0}'.format(team_project_name))
    machine_group_name = public_settings['MachineGroup']
    handler_utility.verify_input_not_null('MachineGroup', machine_group_name)
    handler_utility.log('Machine Group : {0}'.format(machine_group_name))
    agent_name = public_settings['AgentName']
    handler_utility.log('Agent Name : {0}'.format(agent_name))
    tags_input = None 
    if(public_settings.has_key('Tags')):
      tags_input = public_settings['Tags']
    handler_utility.log('Tags : {0}'.format(tags_input))
    tags = format_tags_input(tags_input)
    agent_working_folder = '{0}/VSTSAgent'.format('')
    handler_utility.log('Working folder for VSTS agent : {0}'.format(agent_working_folder))
    if(not os.path.isdir(agent_working_folder)):
      handler_utility.log('Working folder does not exist. Creating it...')
      os.makedirs(agent_working_folder, 0700)
    handler_utility.log('Done reading config settings from file...')
    ss_code = RMExtensionStatus.rm_extension_status['SuccessfullyReadSettings']['Code']
    sub_status_message = RMExtensionStatus.rm_extension_status['SuccessfullyReadSettings']['Message']
    operation_name = RMExtensionStatus.rm_extension_status['SuccessfullyReadSettings']['operationName']
    handler_utility.set_handler_status(ss_code = ss_code, sub_status_message = sub_status_message, operation_name = operation_name)
    ret_val = {
             'VSTSUrl':vsts_url,
             'VirtualApplication':virtual_application,
             'Collection':collection,
             'PATToken':pat_token, 
             'Platform':platform_value, 
             'TeamProject':team_project_name, 
             'MachineGroup':machine_group_name, 
             'AgentName':agent_name, 
             'Tags' : tags,
             'AgentWorkingFolder':agent_working_folder
          }
    return ret_val
  except Exception as e:
    handler_utility.set_handler_error_status(e, RMExtensionStatus.rm_extension_status['ReadingSettings']['operationName'])
    exit_with_code_zero()

def test_configured_agent_exists():
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
    handler_utility.set_handler_error_status(e,RMExtensionStatus.rm_extension_status['PreCheckingDeploymentAgent']['operationName'])
    exit_with_code_zero()

def test_agent_configuration_required(config):
  try:
    ss_code = RMExtensionStatus.rm_extension_status['CheckingAgentReConfigurationRequired']['Code']
    sub_status_message = RMExtensionStatus.rm_extension_status['CheckingAgentReConfigurationRequired']['Message']
    operation_name = RMExtensionStatus.rm_extension_status['CheckingAgentReConfigurationRequired']['operationName']
    handler_utility.set_handler_status(ss_code = ss_code, sub_status_message = sub_status_message, operation_name = operation_name)
    handler_utility.log('Invoking script to check existing agent settings with given configuration settings...')
    config_required = ConfigureDeploymentAgent.test_agent_configuration_required_internal(config['VSTSUrl'], config['VirtualApplication'], config['PATToken'], config['MachineGroup'], config['TeamProject'], config['AgentWorkingFolder'], handler_utility.log)
    ss_code = RMExtensionStatus.rm_extension_status['AgentReConfigurationRequiredChecked']['Code']
    sub_status_message = RMExtensionStatus.rm_extension_status['AgentReConfigurationRequiredChecked']['Message']
    operation_name = RMExtensionStatus.rm_extension_status['AgentReConfigurationRequiredChecked']['operationName']
    handler_utility.set_handler_status(ss_code = ss_code, sub_status_message = sub_status_message, operation_name = operation_name)
    handler_utility.log('Done pre-checking for agent re-configuration, AgentReconfigurationRequired : {0}'.format(config_required))
    return config_required
  except Exception as e:
    handler_utility.set_handler_error_status(e,RMExtensionStatus.rm_extension_status['CheckingAgentReConfigurationRequired']['operationName'])
    exit_with_code_zero()

def execute_agent_pre_check():
  global config, configured_agent_exists, agent_configuration_required
  configured_agent_exists = test_configured_agent_exists()
  if(configured_agent_exists == True):
    agent_configuration_required = test_agent_configuration_required(config)

def get_agent():
  global config
  try:
    ss_code = RMExtensionStatus.rm_extension_status['DownloadingDeploymentAgent']['Code']
    sub_status_message = RMExtensionStatus.rm_extension_status['DownloadingDeploymentAgent']['Message']
    operation_name = RMExtensionStatus.rm_extension_status['DownloadingDeploymentAgent']['operationName']
    handler_utility.set_handler_status(ss_code = ss_code, sub_status_message = sub_status_message, operation_name = operation_name)
    handler_utility.log('Invoking function to download Deployment agent package...')
    DownloadDeploymentAgent.download_deployment_agent(config['VSTSUrl'], '', config['PATToken'], config['Platform'], config['AgentWorkingFolder'], handler_utility.log)
    handler_utility.log('Done downloading Deployment agent package...')
    ss_code = RMExtensionStatus.rm_extension_status['DownloadedDeploymentAgent']['Code']
    sub_status_message = RMExtensionStatus.rm_extension_status['DownloadedDeploymentAgent']['Message']
    operation_name = RMExtensionStatus.rm_extension_status['DownloadedDeploymentAgent']['operationName']
    handler_utility.set_handler_status(ss_code = ss_code, sub_status_message = sub_status_message, operation_name = operation_name)
  except Exception as e:
    handler_utility.set_handler_error_status(e, RMExtensionStatus.rm_extension_status['DownloadingDeploymentAgent']['operationName'])
    exit_with_code_zero()

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
    if(configured_agent_exists == True):
      ss_code = RMExtensionStatus.rm_extension_status['RemovingAndConfiguringDeploymentAgent']['Code']
      sub_status_message = RMExtensionStatus.rm_extension_status['RemovingAndConfiguringDeploymentAgent']['Message']
      operation_name = RMExtensionStatus.rm_extension_status['RemovingAndConfiguringDeploymentAgent']['operationName']
      handler_utility.set_handler_status(ss_code = ss_code, sub_status_message = sub_status_message, operation_name = operation_name)
      handler_utility.log('Removing existing agent and configuring again...')
    else:
      ss_code = RMExtensionStatus.rm_extension_status['ConfiguringDeploymentAgent']['Code']
      sub_status_message = RMExtensionStatus.rm_extension_status['ConfiguringDeploymentAgent']['Message']
      operation_name = RMExtensionStatus.rm_extension_status['ConfiguringDeploymentAgent']['operationName']
      handler_utility.set_handler_status(ss_code = ss_code, sub_status_message = sub_status_message, operation_name = operation_name)
      handler_utility.log('Configuring Deployment agent...')
    vsts_url = config['VSTSUrl']
    if(is_on_prem):
      vsts_url = vsts_url + '/' + config['VirtualApplication']
    ConfigureDeploymentAgent.configure_agent(vsts_url, config['PATToken'], config['TeamProject'], config['MachineGroup'], config['AgentName'], config['AgentWorkingFolder'], configured_agent_exists, handler_utility.log)
    handler_utility.log('Done configuring Deployment agent')
    ss_code = RMExtensionStatus.rm_extension_status['ConfiguredDeploymentAgent']['Code']
    sub_status_message = RMExtensionStatus.rm_extension_status['ConfiguredDeploymentAgent']['Message']
    operation_name = RMExtensionStatus.rm_extension_status['ConfiguredDeploymentAgent']['operationName']
    handler_utility.set_handler_status(ss_code = ss_code, sub_status_message = sub_status_message, operation_name = operation_name)
    code = RMExtensionStatus.rm_extension_status['Installed']['Code']
    message = RMExtensionStatus.rm_extension_status['Installed']['Message']
    handler_utility.set_handler_status(code = code, status = 'success', message = message)
  except Exception as e:
    handler_utility.set_handler_error_status(e, RMExtensionStatus.rm_extension_status['ConfiguringDeploymentAgent']['operationName'])
    exit_with_code_zero()

def remove_existing_agent(config):
  try:
    handler_utility.log('Agent removal started')
    ConfigureDeploymentAgent.remove_existing_agent_internal(config['PATToken'], config['AgentWorkingFolder'], handler_utility.log)
    ss_code = RMExtensionStatus.rm_extension_status['RemovedAgent']['Code']
    sub_status_message = RMExtensionStatus.rm_extension_status['RemovedAgent']['Message']
    operation_name = RMExtensionStatus.rm_extension_status['RemovedAgent']['operationName']
    handler_utility.set_handler_status(ss_code = ss_code, sub_status_message = sub_status_message, operation_name = operation_name)
    code = RMExtensionStatus.rm_extension_status['Uninstalling']['Code']
    message = RMExtensionStatus.rm_extension_status['Uninstalling']['Message']
    handler_utility.set_handler_status(code = code, status = 'success', message = message)
  except Exception as e:
    handler_utility.set_handler_error_status(e, RMExtensionStatus.rm_extension_status['Uninstalling']['operationName'])
    exit_with_code_zero()

def remove_existing_agent_if_required():
  global configured_agent_exists, agent_configuration_required, config
  if((configured_agent_exists == True) and (agent_configuration_required == True)):
    handler_utility.log('Remove existing configured agent')
    remove_existing_agent(config)

def configure_agent_if_required():
  if(agent_configuration_required):
    register_agent()
  else:
    ss_code = RMExtensionStatus.rm_extension_status['SkippingAgentConfiguration']['Code']
    sub_status_message = RMExtensionStatus.rm_extension_status['SkippingAgentConfiguration']['Message']
    operation_name = RMExtensionStatus.rm_extension_status['SkippingAgentConfiguration']['operationName']
    handler_utility.set_handler_status(ss_code = ss_code, sub_status_message = sub_status_message, operation_name = operation_name)


def add_agent_tags():
  if(config['Tags'] !=None and len(config['Tags']) > 0):
    handler_utility.log('Adding tags to configured agent - {0}'.format(str(config['Tags'])))
    try:
      tags_string = json.dumps(config['Tags'], ensure_ascii = False)
      ConfigureDeploymentAgent.add_agent_tags_internal(config['VSTSUrl'], config['TeamProject'], config['PATToken'], config['AgentWorkingFolder'], tags_string, handler_utility.log)
      ss_code = RMExtensionStatus.rm_extension_status['AgentTagsAdded']['Code']
      sub_status_message = RMExtensionStatus.rm_extension_status['AgentTagsAdded']['Message']
      operation_name = RMExtensionStatus.rm_extension_status['AgentTagsAdded']['operationName']
      handler_utility.set_handler_status(ss_code = ss_code, sub_status_message = sub_status_message, operation_name = operation_name)
      code = RMExtensionStatus.rm_extension_status['AgentTagsAdded']['Code']
      message = RMExtensionStatus.rm_extension_status['AgentTagsAdded']['Message']
      handler_utility.set_handler_status(code = code, status = 'success', message = message)
    except Exception as e:
      handler_utility.set_handler_error_status(e, RMExtensionStatus.rm_extension_status['AgentTagsAdded']['operationName'])
      exit_with_code_zero()
  else:
    handler_utility.log('No tags provided for agent')

def enable():
  global configured_agent_exists, agent_configuration_required, config
  input_operation = 'enable'
  start_rm_extension_handler(input_operation)
  config = get_configutation_from_settings()
  execute_agent_pre_check()
  download_agent_if_required()
  remove_existing_agent_if_required()
  configure_agent_if_required()
  add_agent_tags()
  set_last_sequence_number()
  handler_utility.log('Extension is enabled. Removing any disable markup file..')
  remove_extension_disabled_markup()

def disable():
  working_folder = '{0}/VSTSAgent'.format('')
  agent_exists = ConfigureDeploymentAgent.test_configured_agent_exists_internal(working_folder, handler_utility.log)
  handler_utility.log('Disable command is no-op for agent')
  handler_utility.log('Creating a markup file...')
  operation = 'disable'
  handler_utility.do_parse_context(operation)
  set_extension_disabled_markup()
  ss_code = RMExtensionStatus.rm_extension_status['Disabled']['Code']
  sub_status_message = RMExtensionStatus.rm_extension_status['Disabled']['Message']
  operation_name = RMExtensionStatus.rm_extension_status['Disabled']['operationName']
  handler_utility.set_handler_status(ss_code = ss_code, sub_status_message = sub_status_message, operation_name = operation_name)
  code = RMExtensionStatus.rm_extension_status['Disabled']['Code']
  message = RMExtensionStatus.rm_extension_status['Disabled']['Message']
  handler_utility.set_handler_status(code = code, status = 'success', message = message)

def uninstall():
  global configured_agent_exists, config
  operation = 'uninstall'
  config = get_configutation_from_settings()
  configured_agent_exists = test_configured_agent_exists()
  config_path = ConfigureDeploymentAgent.get_agent_listener_path(config['AgentWorkingFolder'])
  if(configured_agent_exists == True):
    remove_existing_agent(config)
  else:
    code = RMExtensionStatus.rm_extension_status['Uninstalling']['Code']
    message = RMExtensionStatus.rm_extension_status['Uninstalling']['Message']
    handler_utility.set_handler_status(code = code, status = 'success', message = message)

def main():
  waagent.LoggerInit('/var/log/waagent.log','/dev/stdout')
  waagent.Log('VSTS machine group extension handler started.')
  if(len(sys.argv) == 2):
    global handler_utility
    handler_utility = Util.HandlerUtility(waagent.Log, waagent.Error)
    operation = sys.argv[1]
    handler_utility.do_parse_context(operation)
    try:
      check_python_version()
      install_dependencies()
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
      handler_utility.set_handler_error_status(e, 'Some error occured')
      exit_with_code_zero()

if(__name__ == '__main__'):
  main()

