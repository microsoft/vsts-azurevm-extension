import sys
from Utils.WAAgentUtil import waagent
import Utils.HandlerUtil as Util
import Utils.RMExtensionStatus as RMExtensionStatus
import os
import subprocess
import base64
import httplib
import urllib
import tarfile
import platform
import Constants
import json
#import RMExtensionHandler

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
  handler_utility.log('Testing whether deleted markup file exists: ' + markup_file)
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
      handler_utility.set_handler_status(ss_code = RMExtensionStatus.rm_extension_status['SkippedInstallation']['Code'], sub_status_message = RMExtensionStatus.rm_extension_status['SkippedInstallation']['Message'], operationName = RMExtensionStatus.rm_extension_status['SkippedInstallation']['operationName'])
      exit_with_code_0
    handler_utility.clear_status_file()
    handler_utility.set_handler_status(code = RMExtensionStatus.rm_extension_status['Installing']['Code'], message = RMExtensionStatus.rm_extension_status['Installing']['Message'])
    handler_utility.set_handler_status(ss_code = RMExtensionStatus.rm_extension_status['Initialized']['Code'], sub_status_message = RMExtensionStatus.rm_extension_status['Initialized']['Message'], operation = RMExtensionStatus.rm_extension_status['Initialized']['operationName'])
  except Exception as e:
    handler_utility.set_handler_error_status(e, RMExtensionStatus.rm_extension_status['Initializing']['operationName'])
    exit_with_code_0()

def get_configutation_from_settings():
  try:
    public_settings = handler_utility.get_public_settings()
    protected_settings = handler_utility.get_protected_settings()
    if(public_settings == None):
      public_settings = {}
    if(protected_settings == None):
      protected_settings = {}
    os_version = handler_utility.get_os_version()
    if(os_version['IsX64'] != True):
     raise new_handler_terminating_error(RMExtensionStatus.rm_extension_status['ArchitectureNotSupported']['Code'], RMExtensionStatus.rm_extension_status['ArchitectureNotSupported']['Message'])
    platform = Constants.platform
    handler_utility.log("Platform: {0}".format(platform))
    vsts_url = public_settings['VSTSAccountUrl']
    handler_utility.verify_input_not_null('VSTSAccountUrl', vsts_url)
    if(vsts_url.startswith('http://')):
      vsts_url = vsts_url[7:]
    elif(vsts_url.startswith('https://')):
      vsts_url = vsts_url[8:]
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
    handler_utility.set_handler_status(ss_code = RMExtensionStatus.rm_extension_status['SuccessfullyReadSettings']['Code'], sub_status_message = RMExtensionStatus.rm_extension_status['SuccessfullyReadSettings']['Message'], operation = RMExtensionStatus.rm_extension_status['SuccessfullyReadSettings']['operationName'])
    ret_val = {
             'VSTSUrl':vsts_url,
             'PATToken':pat_token, 
             'Platform':platform, 
             'TeamProject':team_project_name, 
             'MachineGroup':machine_group_name, 
             'AgentName':agent_name, 
             'AgentWorkingFolder':agent_working_folder
          }
    return ret_val
  except Exception as e:
    handler_utility.set_handler_error_status(e, RMExtensionStatus.rm_extension_status['ReadingSettings']['operationName'])
    exit_with_code_0()

def write_log(log_message, log_function):
  log = '[Agent Checker]: {0}'.format(log_message)
  if(log_function is not None):
    log_function(log)

def test_configured_agent_exists(working_folder, log_function):
  try:
    write_log("Initialization for deployment agent started.", log_function)
    # Is Python version check required here?
    write_log("Check if existing agent is running from {0}".format(working_folder), log_function)
    agent_path = os.path.join(working_folder, Constants.agent_setting)
    agent_settings_file_exists = os.path.isfile(agent_path)
    write_log('\t\t Agent setting file exists : {0}'.format(agent_settings_file_exists), log_function)
    return agent_settings_file_exists
  except Exception as e:
    write_log(e.message, log_function)
    raise e

def test_agent_already_exists_internal(config):
  agent_already_exists = test_configured_agent_exists(config['AgentWorkingFolder'], handler_utility.log)
  return agent_already_exists

def test_agent_already_exists(config):
  try:
    handler_utility.set_handler_status(ss_code = RMExtensionStatus.rm_extension_status['PreCheckingDeploymentAgent']['Code'], sub_status_message = RMExtensionStatus.rm_extension_status['PreCheckingDeploymentAgent']['Message'], operation = RMExtensionStatus.rm_extension_status['PreCheckingDeploymentAgent']['operationName'])
    handler_utility.log("Invoking script to pre-check agent configuration...")
    agent_already_exists = test_agent_already_exists_internal(config)
    handler_utility.log("Done pre-checking agent configuration")
    handler_utility.set_handler_status(ss_code = RMExtensionStatus.rm_extension_status['PreCheckedDeploymentAgent']['Code'], sub_status_message = RMExtensionStatus.rm_extension_status['PreCheckedDeploymentAgent']['Message'], operation = RMExtensionStatus.rm_extension_status['PreCheckedDeploymentAgent']['operationName'])
    return agent_already_exists
  except Exception as e:
    handler_utility.set_handler_error_status(e,RMExtensionStatus.rm_extension_status['PreCheckingDeploymentAgent']['operationName'])
    exit_with_code_0()

def write_download_log(log_message, log_function):
  log = '[Download]: ' + log_message
  if(log_function is not None):
    log_function(log)

def construct_package_data_address(tfs_url, platform, log_function):
  package_data_address = "/_apis/distributedtask/packages/agent/{0}?top=1&api-version={1}".format(platform, Constants.download_api_version)
  write_download_log('\t\t Package data adderss' + package_data_address, log_function)
  return package_data_address

def get_agent_package_data(tfs_url, package_data_address, user_name, pat_token, log_function):
  write_download_log('\t\t Form the header for invoking the rest call', log_function)
  basic_auth = '{0}:{1}'.format(user_name, pat_token)
  #Todo Shlold be converted to byte array? unicode?
  basic_auth = base64.b64encode(basic_auth)
  headers = {
              'Authorization' : 'Basic {0}'.format(basic_auth)
            }
  write_download_log('\t\t Invoke rest call for package data', log_function)
  conn = httplib.HTTPSConnection(tfs_url)
  conn.request('GET', package_data_address, headers = headers)
  response = conn.getresponse()
  #Should response be json parsd?
  write_download_log('\t\t Agent Package Data : {0}'.format(response), log_function)
  val = json.loads(response.read())
  return val['value'][0]

def get_agent_download_url(tfs_url, platform, user_name, pat_token, log_function):
  package_data_address = construct_package_data_address(tfs_url, platform, log_function)
  write_download_log('\t\tGet Agent PackageData using (0)'.format(package_data_address), log_function)
  package_data = get_agent_package_data(tfs_url, package_data_address, user_name, pat_token, log_function)
  write_download_log('Deployment Agent download url - {0}'.format(package_data['downloadUrl']), log_function)
  return package_data['downloadUrl']

def get_target_targz_path(working_folder, agent_targz_name):
  #Assumption. program launched by root user
  #if(not os.path.isdir(working_folder)):
  #  os.mkdir(working_folder)
  return os.path.join(working_folder, agent_targz_name)

def download_deployment_agent_internal(agent_download_url, target, log_function):
  if(os.path.isfile(target)):
    write_download_log('\t\t {0} already exists, deleting it'.format(target), log_function)
    os.remove(target)
  write_download_log('\t\t Start Deployment Agent download', log_function)
  urllib.urlretrieve(agent_download_url, target)
  write_download_log('\t\t Deployment Agent download done', log_function)

def extract_targz(source_targz_file, target):
  tf = tarfile.open(source_targz_file, 'r:gz')
  tf.extractall(target)

def download_deployment_agent(tfs_url, user_name, platform, pat_token, working_folder, log_function):
  if(user_name is None or user_name == ''):
    user_name = ' '
    write_download_log('No user name provided.', log_function)
  write_download_log('Get the url for downloading the agent', log_function)
  agent_download_url = get_agent_download_url(tfs_url, platform, user_name, pat_token, log_function)
  write_download_log('Get the target tar gz file path', log_function)
  agent_targz_file_path = get_target_targz_path(working_folder, Constants.agent_targz_name)
  write_download_log('\t\t Deployment agent will be downloaded at {0}'.format(agent_targz_file_path), log_function)
  write_download_log('Downloaded deployment agent', log_function)
  download_deployment_agent_internal(agent_download_url, agent_targz_file_path, log_function)
  write_download_log('Extract tar gz file {0} to {1}'.format(agent_targz_file_path, working_folder), log_function)
  extract_targz(agent_targz_file_path, working_folder)
  write_download_log('Done with DowloadDeploymentAgent script', log_function)
  return Constants.return_success

def invoke_get_agent_script(config):
  download_deployment_agent(config['VSTSUrl'], '', config['Platform'], config['PATToken'], config['AgentWorkingFolder'], handler_utility.log)

def get_agent(config):
  try:
    handler_utility.set_handler_status(ss_code = RMExtensionStatus.rm_extension_status['DownloadingDeploymentAgent']['Code'], sub_status_message = RMExtensionStatus.rm_extension_status['DownloadingDeploymentAgent']['Message'], operation = RMExtensionStatus.rm_extension_status['DownloadingDeploymentAgent']['operationName'])
    handler_utility.log('Invoking script to download Deployment agent package...')
    invoke_get_agent_script(config)
    handler_utility.log('Done downloading Deployment agent package...')
    handler_utility.set_handler_status(ss_code = RMExtensionStatus.rm_extension_status['DownloadedDeploymentAgent']['Code'], sub_status = 'DownloadedDeploymentAgent', sub_status_message = RMExtensionStatus.rm_extension_status['DownloadedDeploymentAgent']['Message'], operation = RMExtensionStatus.rm_extension_status['DownloadedDeploymentAgent']['operationName'])
  except Exception as e:
    handler_utility.set_handler_error_status(e, RMExtensionStatus.rm_extension_status['DownloadingDeploymentAgent']['operationName'])
    exit_with_code_0()




def enable():
  input_operation = 'enable'
  start_rm_extension_handler(input_operation)
  config = get_configutation_from_settings()
  configured_agent_exists = test_agent_already_exists(config)
  if(not configured_agent_exists):
    get_agent(config)
  else:
    handlerUtility.log('Skipping agent download as a configured agent already exists.')
    SetHandlerStatus(ssCode = RMExtensionStatus.rm_extension_status['SkippingDownloadDeploymentAgent']['Code'], subStatusMessage = RMExtensionStatus.rm_extension_status['SkippingDownloadDeploymentAgent']['Message'], operationName = RMExtensionStatus.rm_extension_status['SkippingDownloadDeploymentAgent']['operationName'])
  #register_agent(config, configured_agent_exists)
  #set_last_sequence_number()
  #handler_utility.log('Extension is enabled. Removing any disable markup file..')
  #remove_extension_disabled_markup()

def check_version():
  version_info = sys.version_info
  major = version_info[0]
  minor = version_info[1]
  #try:
  if(major < 2 or (major == 2 and minor < 6)):    
    raise RMExtensionStatus.new_handler_terminating_error(RMExtensionStatus.rm_extension_status['PythonVersionNotSupported']['Code'], RMExtensionStatus.rm_extension_status['PythonVersionNotSupported']['Message'].format(major + '.' + minor))


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


