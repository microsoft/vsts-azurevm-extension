import os
import subprocess
import json
import platform
import Constants

agent_listener_path = ''
agent_service_path = ''

def write_configuration_log(log_message):
  log = '[Configuration]: ' + log_message
  if(log_function is not None):
    log_function(log)

def write_log(log_message, log_function):
  log = '[Agent Checker]: {0}'.format(log_message)
  if(log_function is not None):
    log_function(log)


def test_configured_agent_exists_internal(working_folder, log_function):
  try:
    agent_setting = Constants.agent_setting
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

def test_agent_configuration_required(vsts_url, machine_group_name, project_name, working_folder):
  agent_setting = Constants.agent_setting
  agent_setting_file =  os.path.join(working_folder, agent_setting)
  with open(agent_setting_file) as f:
    setting_file_contents = f.read()
    setting_params = json.loads(setting_file_contents)
    existing_vsts_url = setting_params['serverUrl']
    existing_machine_group = setting_params['machineGroup']
    existing_project_name = setting_params['projectName']
  f.close()
  if(existing_vsts_url == vsts_url and existing_machine_group == machine_group_name and existing_project_name == project_name):
    return False
  else:
    return True


def get_agent_listener_path(working_folder):
  global agent_listener_path
  if(agent_listener_path == ''):
    agent_listener_path = os.path.join(working_folder, Constants.agent_listener)
  return agent_listener_path

def get_agent_service_path(working_folder):
  global agent_service_path
  if(agent_service_path == ''):
    agent_service_path = os.path.join(working_folder, Constants.agent_service)
  return agent_service_path

def agent_listener_exists(working_folder):
  agent_listener = get_agent_listener_path(working_folder)
  write_configuration_log('\t\t Agent listener file : ' + agent_listener)
  agent_listener_exists = os.path.isfile(agent_listener)
  write_configuration_log('\t\t Agent listener file exists : ' + agent_listener_exists)
  return agent_listener_exists


def remove_existing_agent(pat_token, agent_listener_path, log_func):
  global log_function
  log_function = log_func
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
  agent_listener_path = get_agent_listener_path(working_folder)
  agent_servic_path = get_agent_service_path(working_folder)
  configure_command = Constants.configure_agent_command.format(agent_listener_path, vsts_url, pat_token, agent_name, Constants.default_agent_work_dir, project_name, machine_group_name, machine_group_name)
  #configure_command = Constants.configure_agent_command.format(agent_listener_path, vsts_url, pat_token, agent_name, Constants.default_agent_work_dir, project_name, machine_group_name)
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
  install_service_proc = subprocess.Popen(install_command, shell = True)
  std_out, std_err = config_agent_proc.communicate()
  return_code = install_service_proc.returncode
  write_configuration_log('Service Installation process exit code : {0}'.format(return_code))
  write_configuration_log('stdout : {0}'.format(std_out))
  write_configuration_log('srderr : {0}'.format(std_err))
  if(not (return_code == 0)):
    raise Exception('Service installation failed with error : {0}'.format(std_err))
  start_command = Constants.service_start_command.format(agent_service_path)
  start_service_proc = subprocess.Popen(start_command, shell = True)
  std_out, std_err = config_agent_proc.communicate()
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



