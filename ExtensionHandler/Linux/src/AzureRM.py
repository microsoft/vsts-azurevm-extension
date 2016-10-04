import sys
from Utils.WAAgentUtil import waagent
import Utils.HandlerUtil as Util
import Utils.RMExtensionStatus as RMExtensionStatus
import os
import subprocess
import platform
import Constants
import json
import DownloadDeploymentAgent
#import ConfigureDeploymentAgent

def get_last_sequence_number_file_path():
  return root_dir + '/LASTSEQNUM'

def get_last_sequence_number():
  last_seq_file = get_last_sequence_number_file_path()
  handler_utility.log('Reading last sequence number LASTSEQNUM file {0}'.format(last_seq_file))
  try:
    #Will raise IOError if file does not exist
    with open(last_seq_file) as f:
      contents = f.read()
      return int(contents)
      f.close()
  except IOError as e:
    pass
  except ValueError as e:
    handler_utility.log("Contents of \'Last Sequence File\' not Integer")
    raise e
  return -1

def set_last_sequence_number():
  current_sequence_number = handler_utility._context._seq_no
  last_seq_file = get_last_sequence_number_file_path()
  handler_utility.log('Writing current sequence number {0} to LASTSEQNUM file {1}'.format(current_sequence_number, last_seq_file))
  with open(last_seq_file, 'w') as f:
    f.write(current_sequence_number)
    f.close()


def test_extension_disabled_markup():
  markup_file = root_dir + '/EXTENSIONDISABLED'
  handler_utility.log('Testing whether disabled markup file exists: ' + markup_file)
  if(os.dir.isfile(markup_file)):
    return True
  else:
    return False

def remove_extension_disabled_markup():
  markup_file = root_dir + '/EXTENSIONDISABLED'
  handler_utility.log('Deleting disabled markup file ' + markup_file)
  if(os.path.isfile(markup_file)):
    os.remove(markup_file)

def exit_with_code_0():
  sys.exit(0)

def start_rm_extension_handler(operation):
  try:
    handler_utility.do_parse_context(operation)
    sequence_number = handler_utility._context._seq_no
    last_sequence_number = get_last_sequence_number()
    if((sequence_number == last_sequence_number) and not(test_extension_disabled_markup())):
      handler_utility.log(RMExtensionStatus['SkippedInstallation']['Message'])
      handler_utility.log('Current sequence number : ' + sequence_number + ', last sequence number : ' + last_sequence_number)
      ss_code = RMExtensionStatus.rm_extension_status['SkippedInstallation']['Code']
      sub_status_message = RMExtensionStatus.rm_extension_status['SkippedInstallation']['Message']
      operation_name = RMExtensionStatus.rm_extension_status['SkippedInstallation']['operationName']
      handler_utility.set_handler_status(ss_code = ss_code, sub_status_message = sub_status_message, operation_name = operation_name)
      exit_with_code_0
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
    exit_with_code_0()

def get_platform_value():
  info = platform.linux_distribution()
  os_distr_name = info[0]
  if(os_distr_name == 'Red Hat Enterprise Linux Server'):
    os_distr_name = 'rhel'
  elif(os_distr_name == 'Ubuntu'):
    os_distr_name = 'ubuntu'
  version_no = info[1].split('.')[0]
  sub_version = info[1].split('.')[1]
  platform_value = Constants.platform_format.format(os_distr_name, version_no, sub_version, 'x64')
  return platform_value

def check_account_name_prefix(account_name):
  prefix_1 = 'http://'
  prefix_2 = 'https://'
  account_name_lower = account_name.lower()
  ans = (account_name_lower.startswith(prefix_1) or account_name_lower.startswith(prefix_2))
  return ans 

def check_account_name_suffix(account_name):
  suffix_1 = 'vsallin.net'
  suffix_2 = 'tfsallin.net'
  suffix_3 = 'visualstudio.com'
  account_name_lower = account_name.lower()
  ans = (account_name_lower.endswith(suffix_1) or account_name_lower.endswith(suffix_2) or account_name_lower.endswith(suffix_3)) 
  return ans

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
    handler_utility.log("Platform: {0}".format(platform_value))
    vsts_account_name = public_settings['VSTSAccountName']
    handler_utility.verify_input_not_null('VSTSAccountName', vsts_account_name)
    if(not (check_account_name_prefix(vsts_account_name) and check_account_name_suffix(vsts_account_name))):
      vsts_url = format_string.format(vsts_account_name)
    else:
      vsts_url = vsts_account_name
    handler_utility.log('VSTS service URL : {0}'.format(vsts_url))
    pat_token = ''
    if(protected_settings.has_key('PATToken')):
      pat_token = protected_settings['PATToken']
    if(pat_token == ''):
      pat_token = public_settings['PATToken']
      handler_utility.verify_input_not_null('PATToken', pat_token)
    team_project_name = public_settings['TeamProject']
    handler_utility.verify_input_not_null('TeamProject', team_project_name)
    handler_utility.log('Team Project : (0)'.format(team_project_name))
    machine_group_name = public_settings['MachineGroup']
    handler_utility.verify_input_not_null('MachineGroup', machine_group_name)
    handler_utility.log('Machine Group : {0}'.format(machine_group_name))
    agent_name = public_settings['AgentName']
    handler_utility.log('Agent Name : {0}'.format(agent_name))
    agent_working_folder = '{0}/VSTSAgent'.format(waagent.LibDir)
    handler_utility.log('Working folder for VSTS agent : {0}'.format(agent_working_folder))
    #Check for links
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
             'PATToken':pat_token, 
             'Platform':platform_value, 
             'TeamProject':team_project_name, 
             'MachineGroup':machine_group_name, 
             'AgentName':agent_name, 
             'AgentWorkingFolder':agent_working_folder
          }
    return ret_val
  except Exception as e:
    print e.message
    print e.args
    handler_utility.set_handler_error_status(e, RMExtensionStatus.rm_extension_status['ReadingSettings']['operationName'])
    exit_with_code_0()

def write_log(log_message, log_function):
  log = '[Agent Checker]: {0}'.format(log_message)
  if(log_function is not None):
    log_function(log)

def test_configured_agent_exists_internal(working_folder, agent_setting , log_function):
  try:
    write_log("Initialization for deployment agent started.", log_function)
    # Is Python version check required here?
    write_log("Checking if existing agent is running from {0}".format(working_folder), log_function)
    agent_path = os.path.join(working_folder, agent_setting)
    agent_setting_file_exists = os.path.isfile(agent_path)
    write_log('\t\t Agent setting file exists : {0}'.format(agent_setting_file_exists), log_function)
    return agent_setting_file_exists
  except Exception as e:
    write_log(e.message, log_function)
    raise e

def test_configured_agent_exists(config):
  try:
    ss_code = RMExtensionStatus.rm_extension_status['PreCheckingDeploymentAgent']['Code']
    sub_status_message = RMExtensionStatus.rm_extension_status['PreCheckingDeploymentAgent']['Message']
    operation_name = RMExtensionStatus.rm_extension_status['PreCheckingDeploymentAgent']['operationName']
    handler_utility.set_handler_status(ss_code = ss_code, sub_status_message = sub_status_message, operation_name = operation_name)
    handler_utility.log("Invoking function to pre-check agent configuration...")
    agent_already_exists = test_configured_agent_exists_internal(config['AgentWorkingFolder'], Constants.agent_setting, handler_utility.log)
    handler_utility.log("Done pre-checking agent configuration")
    ss_code = RMExtensionStatus.rm_extension_status['PreCheckedDeploymentAgent']['Code']
    sub_status_message = RMExtensionStatus.rm_extension_status['PreCheckedDeploymentAgent']['Message']
    operation_name = RMExtensionStatus.rm_extension_status['PreCheckedDeploymentAgent']['operationName']
    handler_utility.set_handler_status(ss_code = ss_code, sub_status_message = sub_status_message, operation_name = operation_name)
    return agent_already_exists
  except Exception as e:
    handler_utility.set_handler_error_status(e,RMExtensionStatus.rm_extension_status['PreCheckingDeploymentAgent']['operationName'])
    exit_with_code_0()


def get_agent(config):
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
    exit_with_code_0()
"""
def register_agent(config, agent_exists):
  try:
    if(agent_exists == True):
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
    ConfigureDeploymentAgent.configure_deployment_agent(config['VSTSUrl'], '', config['PATToken'], config['TeamProject'], config['MachineGroup'], config['AgentName'], config['AgentWorkingFolder'], agent_exists, handler_utility.log)
    handler_utility.log('Done configuring Deployment agent')
    ss_code = RMExtensionStatus.rm_extension_status['ConfiguredDeploymentAgent']['Code']
    sub_status_message = RMExtensionStatus.rm_extension_status['ConfiguredDeploymentAgent']['Message']
    operation_name = RMExtensionStatus.rm_extension_status['ConfiguredDeploymentAgent']['operationName']
    handler_utility.set_handler_status(ss_code = ss_code, sub_status_message = sub_status_message, operation_name = operation_name)
    code = RMExtensionStatus.rm_extension_status['Installed']['Code']
    message = RMExtensionStatus.rm_extension_status['Installed']['Message']
    handler_utility.set_handler_status(code = code, status = 'success', message = message)
  except Exception as e:
    set_handler_error_status(e, RMExtensionStatus.rm_extension_status['ConfiguringDeploymentAgent']['operationName']
    exit_with_code_0
"""
def enable():
  input_operation = 'enable'
  start_rm_extension_handler(input_operation)
  config = get_configutation_from_settings()
  agent_exists = test_configured_agent_exists(config)
  if(not agent_exists):
    get_agent(config)
  else:
    handlerUtility.log('Skipping agent download as agent already exists.')
    ss_code = RMExtensionStatus.rm_extension_status['SkippingDownloadDeploymentAgent']['Code']
    sub_status_message = RMExtensionStatus.rm_extension_status['SkippingDownloadDeploymentAgent']['Message']
    operation_name = RMExtensionStatus.rm_extension_status['SkippingDownloadDeploymentAgent']['operationName']
    handler_utility.set_handler_status(ss_code = ss_code, sub_status_message = sub_status_message, operation_name = operation_name)
  #register_agent(config, agent_exists)
  #set_last_sequence_number()
  #handler_utility.log('Extension is enabled. Removing any disable markup file..')
  #remove_extension_disabled_markup()

def check_version():
  version_info = sys.version_info
  major = version_info[0]
  minor = version_info[1]
  #try:
  if(major < 2 or (major == 2 and minor < 6)):
    code = RMExtensionStatus.rm_extension_status['PythonVersionNotSupported']['Code']
    message = RMExtensionStatus.rm_extension_status['PythonVersionNotSupported']['Message'].format(major + '.' + minor)
    raise RMExtensionStatus.new_handler_terminating_error(code, message)


def InvalidArgumentError(Exception):
  def __init__(self, value):
    self.value = value

def main():
  check_version()
  global root_dir
  global handler_utility
  root_dir = os.getcwd()
  waagent.LoggerInit('/var/log/waagent.log','/dev/stdout')
  waagent.Log("Azure RM extension started to handle.")
  handler_utility = Util.HandlerUtility(waagent.Log, waagent.Error)
  if(len(sys.argv) == 2):
    if(sys.argv[1] == '-enable'):
      enable()
    else:
      raise InvalidArgumentError("Invalid input operation. Valid operations are \'enable\'")


if(__name__ == '__main__'):
  main()

"""
class IncorrectUsageError(Exception):
  def __init__(self):
    self.message = 'Incorrect Usage. Correct usage is \'python <filename> enable | disable | install | uninstall\''

"""
