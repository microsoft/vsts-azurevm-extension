import os
import subprocess
import json
import platform
import Constants
import codecs
import base64
import httplib

agent_listener_path = ''
agent_service_path = ''
log_function = None

def write_configuration_log(log_message):
  global log_function
  log = '[Configuration]: ' + log_message
  if(log_function is not None):
    log_function(log)

def write_log(log_message):
  global log_function
  log = '[Agent Checker]: {0}'.format(log_message)
  if(log_function is not None):
    log_function(log)


def test_configured_agent_exists_internal(working_folder, log_func):
  global log_function
  log_function = log_func
  try:
    agent_setting = Constants.agent_setting
    write_log("Initialization for deployment agent started.")
    # Is Python version check required here?
    write_log("Checking if existing agent is running from {0}".format(working_folder))
    agent_path = os.path.join(working_folder, agent_setting)
    agent_setting_file_exists = os.path.isfile(agent_path)
    write_log('\t\t Agent setting file exists : {0}'.format(agent_setting_file_exists))
    return agent_setting_file_exists
  except Exception as e:
    write_log(e.message)
    raise e

def construct_machine_group_name_address(project_name, machine_group_id):
  machine_group_name_address = machine_group_address_format(project_name, machine_group_id)
  return machine_group_name_address

def invoke_url_for_machine_group_name(vsts_url, user_name, pat_token machine_group_name_address):
  write_log('\t\t Form header for making http call')
  if(vsts_url.startswith('http://')):
    vsts_url = vsts_url[7:]
  elif(vsts_url.startswith('https://')):
    vsts_url = vsts_url[8:]
  basic_auth = '{0}:{1}'.format(user_name, pat_token)
  #Todo Shlold be converted to byte array? unicode?
  basic_auth = base64.b64encode(basic_auth)
  headers = {
              'Authorization' : 'Basic {0}'.format(basic_auth)
            }
  write_download_log('\t\t Making HTTP request for machine group name')
  conn = httplib.HTTPSConnection(vsts_url)
  conn.request('GET', machine_group_name_address, headers = headers)
  response = conn.getresponse()
  #Should response be json parsd?
  val = json.loads(response.read())
  write_log('\t\t Machine group details : {0}'.format(val))
  machine_group_name = val['Name']
  return machine_group_name
  

def get_machine_group_name_from_setting(setting_params, vsts_url, project_name, pat_token):
  machine_group_id = ''
  try:
    machine_group_id = setting_params['MachineGroupId']
    write_log('\t\t Machine group id - {0}'.format(machine_group_id))
  except Exception as e:
    pass
  if(machine_group_id == ''):
    machine_group_name_address = construct_machine_group_name_address(project_name, machine_group_id)
    machine_group_name = invoke_url_for_machine_group_name(vsts_url, '', pat_token, machine_group_name_address)
    return machine_group_name
  return setting_params['machineGroupName']

def test_agent_configuration_required(vsts_url, pat_token, machine_group_name, project_name, working_folder, log_func):
  global log_function
  log_function = log_func
  try:
    write_log("AgentReConfigurationRequired check started.")
    agent_setting = Constants.agent_setting
    agent_setting_file =  os.path.join(working_folder, agent_setting)
    setting_params = json.load(codecs.open(agent_setting_file, 'r', 'utf-8-sig'))
    existing_vsts_url = setting_params['serverUrl']
    if(vsts_url[-1] == '/'):
      vsts_url = vsts_url[:-1]
    if(existing_vsts_url[-1] == '/'):
      existing_vsts_url = existing_vsts_url[:-1]
    existing_machine_group_name = ''
    try:
      existing_machine_group_name = get_machine_group_name_from_setting(setting_params, vsts_url, project_name, pat_token)
    except Exception as e:
      write_log('\t\t\t Unable to get the machine group name - {0}'.format(e.message))
    existing_project_name = setting_params['projectName']
    write_log('\t\t\t Agent configured with \t\t\t\t Agent needs to be configured with')
    write_log('\t\t\t {0} \t\t\t\t {1}'.format(existing_vsts_url, vsts_url))
    write_log('\t\t\t {0} \t\t\t\t {1}'.format(existing_project_name, project_name))
    write_log('\t\t\t {0} \t\t\t\t {1}'.format(existing_machine_group_name, machine_group_name))
    if(existing_vsts_url == vsts_url and existing_machine_group_name == machine_group_name and existing_project_name == project_name):
      write_log('\t\t\t test_agent_configuration_required : False') 
      return False
    else:
      write_log('\t\t\t test_agent_configuration_required : True') 
      return True
  except Exception as e:
    write_log(e.message)
    raise e

def get_agent_listener_path(working_folder):
  global agent_listener_path
  if(agent_listener_path == ''):
    agent_listener_path = os.path.join(working_folder, Constants.agent_listener)

def get_agent_service_path(working_folder):
  global agent_service_path
  if(agent_service_path == ''):
    agent_service_path = os.path.join(working_folder, Constants.agent_service)

def agent_listener_exists(working_folder):
  agent_listener = get_agent_listener_path(working_folder)
  write_configuration_log('\t\t Agent listener file : ' + agent_listener)
  agent_listener_exists = os.path.isfile(agent_listener)
  write_configuration_log('\t\t Agent listener file exists : ' + agent_listener_exists)
  return agent_listener_exists


def remove_existing_agent(pat_token, working_folder, log_func):
  global agent_listener_path, agent_service_path, log_function
  log_function = log_func
  get_agent_listener_path(working_folder)
  get_agent_service_path(working_folder) 
  service_stop_proc = subprocess.Popen(Constants.service_stop_command.format(agent_service_path), stdout = subprocess.PIPE, stderr = subprocess.PIPE, shell = True, cwd = working_folder)
  std_out, std_err = service_stop_proc.communicate()
  return_code = service_stop_proc.returncode
  write_configuration_log('Service Stop process exit code : {0}'.format(return_code))
  write_configuration_log('stdout : {0}'.format(std_out))
  write_configuration_log('srderr : {0}'.format(std_err))
  if(not (return_code == 0)):
    raise Exception('Service stop failed with error : {0}'.format(std_err))
  service_uninstall_proc = subprocess.Popen(Constants.service_uninstall_command.format(agent_service_path), stdout = subprocess.PIPE, stderr = subprocess.PIPE, shell = True, cwd = working_folder)
  std_out, std_err = service_uninstall_proc.communicate()
  return_code = service_uninstall_proc.returncode
  write_configuration_log('Service uninstall process exit code : {0}'.format(return_code))
  write_configuration_log('stdout : {0}'.format(std_out))
  write_configuration_log('srderr : {0}'.format(std_err))
  if(not (return_code == 0)):
    raise Exception('Service uninstall failed with error : {0}'.format(std_err))
  remove_agent_proc = subprocess.Popen(Constants.remove_agent_command.format(agent_listener_path, pat_token), stdout = subprocess.PIPE, stderr = subprocess.PIPE, shell = True)
  std_out, std_err = remove_agent_proc.communicate()
  return_code = remove_agent_proc.returncode
  write_configuration_log('RemoveAgentProcess exit code : {0}'.format(return_code))
  write_configuration_log('stdout : {0}'.format(std_out))
  write_configuration_log('srderr : {0}'.format(std_err))
  if(not (return_code == 0)):
    raise Exception('Agent removal failed with error : {0}'.format(std_err))
  

def install_dependencies():
  install_command = ''
  linux_distr = platform.linux_distribution()
  if(linux_distr[0] == Constants.red_hat_distr_name):
    install_command += 'sudo yum -y install libunwind.x86_64 icu'
  elif(linux_distr[0] == Constants.ubuntu_distr_name):
    install_command += 'sudo apt-get install -y libunwind8 libcurl3'
    version = linux_distr[1].split('.')[0]
    if(version == '14'):
      install_command += ' libicu52'     
  proc = subprocess.Popen(install_command, shell = True, stdout = subprocess.PIPE, stderr = subprocess.PIPE)
  install_out, install_err = proc.communicate()
  

def configure_agent_internal(vsts_url, pat_token, project_name, machine_group_name, agent_name, working_folder):
  global agent_listener_path, agent_service_path
  get_agent_listener_path(working_folder)
  get_agent_service_path(working_folder)
  #configure_command = Constants.configure_agent_command.format(agent_listener_path, vsts_url, pat_token, agent_name, Constants.default_agent_work_dir, project_name, machine_group_name, machine_group_name)
  configure_command = Constants.configure_agent_command.format(agent_listener_path, vsts_url, pat_token, agent_name, Constants.default_agent_work_dir, project_name, machine_group_name)
  write_configuration_log('Agent configuration command is {0}'.format(configure_command))
  config_agent_proc = subprocess.Popen(configure_command, shell = True)
  std_out, std_err = config_agent_proc.communicate()
  return_code = config_agent_proc.returncode
  write_configuration_log('Configure Agent Process exit code : {0}'.format(return_code))
  write_configuration_log('stdout : {0}'.format(std_out))
  write_configuration_log('srderr : {0}'.format(std_err))
  if(not (return_code == 0)):
    raise Exception('Agent configuration failed with error : {0}'.format(std_err))
  install_command = Constants.service_install_command.format(agent_service_path)
  write_configuration_log('Service install command is {0}'.format(install_command))
  install_service_proc = subprocess.Popen(install_command, shell = True, cwd = working_folder)
  std_out, std_err = install_service_proc.communicate()
  return_code = install_service_proc.returncode
  write_configuration_log('Service Installation process exit code : {0}'.format(return_code))
  write_configuration_log('stdout : {0}'.format(std_out))
  write_configuration_log('srderr : {0}'.format(std_err))
  if(not (return_code == 0)):
    raise Exception('Service installation failed with error : {0}'.format(std_err))
  start_command = Constants.service_start_command.format(agent_service_path)
  write_configuration_log('Service start command is {0}'.format(start_command))
  start_service_proc = subprocess.Popen(start_command, shell = True, cwd = working_folder)
  std_out, std_err = start_service_proc.communicate()
  return_code = start_service_proc.returncode
  write_configuration_log('Service start process exit code : {0}'.format(return_code))
  write_configuration_log('stdout : {0}'.format(std_out))
  write_configuration_log('srderr : {0}'.format(std_err))
  if(not (return_code == 0)):
    raise Exception('Service start failed with error : {0}'.format(std_err))
  


def configure_agent(vsts_url, pat_token, project_name, machine_group_name, agent_name, working_folder, agent_exists, log_func):
  global agent_listener_path
  global log_function
  log_function = log_func
  try:
    if(not agent_listener_exists):
      raise Exception("Unable to find the agent listener, ensure to download the agent exists before starting the agent configuration")
    if(agent_name is None or agent_name == ''):
      #todo
      agent_name = platform.node() + "-MG"
      write_configuration_log('Agent name not provided, agent name will be set as ' + agent_name)
    write_configuration_log('Configuring agent')
    install_dependencies()
    configure_agent_internal(vsts_url, pat_token, project_name, machine_group_name, agent_name, working_folder)
    return Constants.return_success
  except Exception as e:
    write_configuration_log(e.message)
    raise e



