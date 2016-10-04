import os
import subprocess
import json
import platform

config_command_path = ''
remove_agent_command = '{0} remove --unattended --auth PAT --token {1}'
configure_agent_command = '{0} --unattended --acceptteeeula --url {1} --auth PAT --token {2} --agent {3} --work {4} --projectname {5} --machinegroupname {6} --pool default'


def write_configuration_log(log_message, log_function):
  log = '[Configuration]: ' + log_message
  if(log_function is not None):
    log_function(log)
  else:

def get_config_command_path(working_folder):
  global config_command_path
  if(config_command_path == ''):
    config_command_path = os.path.join(working_folder, Constants.config_file)
    write_configuration_log('\t\t Configuration file path : {0}'.format(config_command_path))
  return config_command_path

def config_file_exists(working_folder):
  config_path = get_config_command_path(working_folder)
  write_configuration_log('\t\t Configuration file : ' + config_path)
  config_file_does_exist = os.path.isfile(config_path)
  write_configuration_log('\t\t Configuration file exists : ' + config_file_does_exist)
  return config_file_does_exist


def remove_existing_agent(pat_token, config_path):
  remove_agent_proc = subprocess.Popen(remove_agent_command.format(config_path, pat_token), stdout = subprocess.PIPE, stderr = subprocess.PIPE, shell = True)
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
  if(linux_distr[0] == 'Red Hat Enterprise Linux Server'):
    install_command += 'sudo yum -y install libunwind.x86_64 icu'
  elif(linux_distr[0] == 'Ububtu'):
    install_command += = 'sudo apt-get install -y libunwind8 libcurl3'
    version = linux_distr[1].split('.')[0]
    if(version == '14'):
      install_command += 'libicu52'     
  proc = subprocess.Popen(install_command, shell = True, stdout = subprocess.PIPE, stderr = subprocess.PIPE)
  install_out, install_err = proc.communicate()
  

def configure_agent(vsts_url, pat_token, project_name, machine_group_name, agent_name, working_folder, log_function):
  config_path = get_config_command_path(working_folder)
  config_agent_proc = subprocess.Popen(configure_agent_command.format(config_path, vsts_url, pat_token, agent_name, '_work', project_name, machine_group_name))
  std_out, std_err = config_agent_proc.communicate()
  return_code = config_agent_proc.returncode
  write_configuration_log('ConfigAgentProcess exit code : {0}'.format(return_code))
  write_configuration_log('stdout : {0}'.format(std_out))
  write_configuration_log('srderr : {0}'.format(std_err))
  if(not (return_code == 0)):
    raise Exception('Agent configuration failed with error : {0}'.format(std_err))

def test_agent_reconfiguration_required(vsts_url, machine_group_name, project_name, working_folder, agent_setting):
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

def configure_deployment_agent(vsts_url, pat_token, project_name, machine_group_name, agent_name, working_folder, agent_exists, log_func):
  global config_command_path
  global log_function
  log_function = log_func
  try:
    if(not config_file_exists):
      raise Exception("Unable to find the configuration cmd, ensure to download the agent exists before starting the agent configuration")
    write_configuration_log('Checking if any existing agent running form ' + working_folder)
    if(agent_exists):
      agent_reconfig_required = test_agent_reconfiguration_required(vsts_url, machine_group_name, project_name, working_folder)
      if(agent_reconfig_required == False):
        return 'No configuration required'
      write_configuration_log('Already a agent is running from ' + working_folder + ',  need to remove it')
      config_path = get_config_command_path(working_folder)
      remove_existing_agent(pat_token, config_path)
    else:
      write_configuration_log('No existing agent found. Configuring.')
    if(agent_name is None or agent_name == ''):
      #todo
      agent_name = platform.node() + "-MG"
      write_configuration_log('Agent name not provided, agent name will be set as ' + agent_name)
    write_configuration_log('Configuring agent')
    install_dependencies()
    configure_agent()
    rerurn Constants.return_success
  except Exception as e:
    write_configuration_log(e.message)
    raise e



