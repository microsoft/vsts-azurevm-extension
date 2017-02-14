import os
import subprocess
import json
import platform
import Constants
import codecs
import base64
import httplib
import time

agent_listener_path = ''
agent_service_path = ''
log_function = None

def write_configuration_log(log_message):
  global log_function
  log = '[Configuration]: {}'.format(log_message)
  if(log_function is not None):
    log_function(log)

def write_log(log_message):
  global log_function
  log = '[Agent Checker]: {0}'.format(log_message)
  if(log_function is not None):
    log_function(log)

def write_add_tags_log(log_message):
  global log_function
  log = '[AddTags]: {0}'.format(log_message)
  if(log_function is not None):
    log_function(log)

def test_configured_agent_exists_internal(working_folder, log_func):
  global log_function
  log_function = log_func
  try:
    agent_setting = Constants.agent_setting
    write_log('Initialization for deployment agent started.')
    write_log('Checking if existing agent is running from {0}'.format(working_folder))
    agent_path = os.path.join(working_folder, agent_setting)
    agent_setting_file_exists = os.path.isfile(agent_path)
    write_log('\t\t Agent setting file exists : {0}'.format(agent_setting_file_exists))
    return agent_setting_file_exists
  except Exception as e:
    write_log(e.message)
    raise e

def construct_machine_group_name_address(project_name, machine_group_id):
  machine_group_name_address = Constants.machine_group_address_format.format(project_name, machine_group_id)
  return machine_group_name_address

def invoke_url_for_machine_group_name(vsts_url, user_name, pat_token, machine_group_name_address):
  write_log('\t\t Form header for making http call')
  method = httplib.HTTPSConnection
  if(vsts_url.startswith('http://')):
    vsts_url = vsts_url[7:]
    method = httplib.HTTPConnection
  elif(vsts_url.startswith('https://')):
    vsts_url = vsts_url[8:]
  basic_auth = '{0}:{1}'.format(user_name, pat_token)
  basic_auth = base64.b64encode(basic_auth)
  headers = {
              'Authorization' : 'Basic {0}'.format(basic_auth)
            }
  write_add_tags_log('\t\t Making HTTP request for machine group name')
  conn = method(vsts_url)
  conn.request('GET', machine_group_name_address, headers = headers)
  response = conn.getresponse()
  if(response.status == 200):
    val = json.loads(response.read())
    write_log('\t\t Machine group details : {0}'.format(val))
    machine_group_name = val['name']
    return machine_group_name
  else:
    raise Exception('Unable to fetch the machine group information from VSTS server.')
  

def get_machine_group_name_from_setting(setting_params, vsts_url, project_name, pat_token):
  machine_group_id = ''
  try:
    machine_group_id = str(setting_params['machineGroupId'])
    write_log('\t\t Machine group id - {0}'.format(machine_group_id))
  except Exception as e:
    pass
  if(machine_group_id != ''):
    machine_group_name_address = construct_machine_group_name_address(project_name, machine_group_id)
    machine_group_name = invoke_url_for_machine_group_name(vsts_url, '', pat_token, machine_group_name_address)
    return machine_group_name
  return setting_params['machineGroupName']

def test_agent_configuration_required_internal(vsts_url, virtual_application, pat_token, machine_group_name, project_name, working_folder, log_func):
  global log_function
  log_function = log_func
  try:
    write_log('AgentReConfigurationRequired check started.')
    agent_setting = Constants.agent_setting
    agent_setting_file =  os.path.join(working_folder, agent_setting)
    setting_params = json.load(codecs.open(agent_setting_file, 'r', 'utf-8-sig'))
    existing_vsts_url = setting_params['serverUrl']
    existing_vsts_url = existing_vsts_url.strip('/')
    existing_machine_group_name = ''
    try:
      existing_machine_group_name = get_machine_group_name_from_setting(setting_params, vsts_url, project_name, pat_token)
    except Exception as e:
      write_log('\t\t\t Unable to get the machine group name - {0}'.format(e.message))
    existing_project_name = setting_params['projectName']
    vsts_url_for_configuration = (vsts_url + '/' + virtual_application).strip('/')
    write_log('\t\t\t Agent configured with \t\t\t\t Agent needs to be configured with')
    write_log('\t\t\t {0} \t\t\t\t {1}'.format(existing_vsts_url, vsts_url_for_configuration))
    write_log('\t\t\t {0} \t\t\t\t {1}'.format(existing_project_name, project_name))
    write_log('\t\t\t {0} \t\t\t\t {1}'.format(existing_machine_group_name, machine_group_name))
    if(existing_vsts_url == vsts_url_for_configuration and existing_machine_group_name == machine_group_name and existing_project_name == project_name):
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
  get_agent_listener_path(working_folder)
  write_configuration_log('\t\t Agent listener file : {0}'.format(agent_listener_path))
  agent_listener_exists = os.path.isfile(agent_listener_path)
  write_configuration_log('\t\t Agent listener file exists : {0}'.format(agent_listener_exists))
  return agent_listener_exists


def remove_existing_agent_internal(pat_token, working_folder, agent_name, log_func):
  try:
    global agent_listener_path, agent_service_path, log_function
    log_function = log_func
    get_agent_listener_path(working_folder)
    get_agent_service_path(working_folder) 
    service_stop_proc = subprocess.Popen(Constants.service_stop_command.format(agent_service_path).split(' '), stdout = subprocess.PIPE, stderr = subprocess.PIPE, cwd = working_folder)
    std_out, std_err = service_stop_proc.communicate()
    return_code = service_stop_proc.returncode
    write_configuration_log('Service Stop process exit code : {0}'.format(return_code))
    write_configuration_log('stdout : {0}'.format(std_out))
    write_configuration_log('srderr : {0}'.format(std_err))
    if(not (return_code == 0)):
      raise Exception('Service stop failed with error : {0}'.format(std_err))
    service_uninstall_proc = subprocess.Popen(Constants.service_uninstall_command.format(agent_service_path).split(' '), stdout = subprocess.PIPE, stderr = subprocess.PIPE, cwd = working_folder)
    std_out, std_err = service_uninstall_proc.communicate()
    return_code = service_uninstall_proc.returncode
    write_configuration_log('Service uninstall process exit code : {0}'.format(return_code))
    write_configuration_log('stdout : {0}'.format(std_out))
    write_configuration_log('srderr : {0}'.format(std_err))
    if(not (return_code == 0)):
      raise Exception('Service uninstall failed with error : {0}'.format(std_err))
    remove_agent_proc = subprocess.Popen(Constants.remove_agent_command.format(agent_listener_path, pat_token).split(' '), stdout = subprocess.PIPE, stderr = subprocess.PIPE)
    std_out, std_err = remove_agent_proc.communicate()
    return_code = remove_agent_proc.returncode
    write_configuration_log('RemoveAgentProcess exit code : {0}'.format(return_code))
    write_configuration_log('stdout : {0}'.format(std_out))
    write_configuration_log('srderr : {0}'.format(std_err))
    if(not (return_code == 0)):
      cur_time = '%.6f'%(time.time())
      old_agent_folder_name = working_folder + cur_time
      write_configuration_log('Failed to unconfigure the VSTS agent. Renaming the agent directory to {0}.'.format(old_agent_folder_name))
      write_configuration_log('Please delete the agent {0} manually from the machine group.'.format(agent_name))
      remove_agent_proc = subprocess.Popen('mv {0} {1}'.format(working_folder, old_agent_folder_name).split(' '), stdout = subprocess.PIPE, stderr = subprocess.PIPE)
      std_out, std_err = remove_agent_proc.communicate()
      return_code = remove_agent_proc.returncode
      write_configuration_log('Renaming agent directory process exit code : {0}'.format(return_code))
      write_configuration_log('stdout : {0}'.format(std_out))
      write_configuration_log('srderr : {0}'.format(std_err))
      if(not (return_code == 0)):
        raise Exception('Deletion of agent directory failed with error : {0}'.format(std_err))
  except Exception as e:
    write_configuration_log(e.message)
    raise e

def apply_tags_to_agent(vsts_url, pat_token, project_name, machine_group_id, agent_id, tags_string):
  method = httplib.HTTPSConnection
  if(vsts_url.startswith('http://')):
    vsts_url = vsts_url[7:]
    method = httplib.HTTPConnection
  elif(vsts_url.startswith('https://')):
    vsts_url = vsts_url[8:]
  basic_auth = '{0}:{1}'.format('', pat_token)
  basic_auth = base64.b64encode(basic_auth)
  headers = {
              'Authorization' : 'Basic {0}'.format(basic_auth),
              'Content-Type' : 'application/json'
            }
  tags_address = Constants.machines_address_format.format(project_name, machine_group_id, Constants.tags_api_version)
  request_body = json.dumps([{'tags' : json.loads(tags_string), 'agent' : {'id' : agent_id}}])
  write_add_tags_log('Add tags request body : {0}'.format(request_body))
  conn = method(vsts_url)
  conn.request('PATCH', tags_address, headers = headers, body = request_body)
  response = conn.getresponse()
  if(response.status == 200):
    write_add_tags_log('Patch call for tags succeeded')
  else:
    raise Exception('Tags could not be added. Please make sure that you enter correct details.')


def add_tags_to_agent(vsts_url, pat_token, project_name, machine_group_id, agent_id, tags_string):
  method = httplib.HTTPSConnection
  if(vsts_url.startswith('http://')):
    vsts_url = vsts_url[7:]
    method = httplib.HTTPConnection
  elif(vsts_url.startswith('https://')):
    vsts_url = vsts_url[8:]
  basic_auth = '{0}:{1}'.format('', pat_token)
  basic_auth = base64.b64encode(basic_auth)
  headers = {
              'Authorization' : 'Basic {0}'.format(basic_auth)
            }
  tags_address = Constants.machines_address_format.format(project_name, machine_group_id, Constants.tags_api_version)
  conn = method(vsts_url)
  conn.request('GET', tags_address, headers = headers)
  response = conn.getresponse()
  if(response.status == 200):
    val = {}
    response_string = response.read()
    val = json.loads(response_string)
    existing_tags = []
    for i in range(0, val['count']):
      each_machine = val['value'][i]
      if(each_machine != None and each_machine.has_key('agent') and each_machine['agent']['id'] == agent_id):
        if(each_machine.has_key('tags')):
          existing_tags = each_machine['tags']
          break
    tags = json.loads(tags_string)
    for x in tags:
      if(x.lower() not in map(lambda x:x.lower(), existing_tags)):
        existing_tags.append(x)
    tags = existing_tags
  else:
    raise Exception('Tags could not be added. Unable to fetch the existing tags.')
  apply_tags_to_agent(vsts_url, pat_token, project_name, machine_group_id, agent_id, json.dumps(tags, ensure_ascii = False))
 
def add_agent_tags_internal(vsts_url, project_name, pat_token, working_folder, tags_string, log_func):
  global log_function
  log_function = log_func
  try:
    write_add_tags_log('Adding the tags for configured agent')
    agent_setting_file_path = os.path.join(working_folder, Constants.agent_setting)
    write_add_tags_log('\t\t Agent setting path : {0}'.format(agent_setting_file_path))
    if(not(os.path.isfile(agent_setting_file_path))):
      raise Exception('Unable to find the .agent file {0}. Ensure that the agent is configured before adding tags.'.format(agent_setting_file_path))
    setting_params = json.load(codecs.open(agent_setting_file_path, 'r', 'utf-8-sig'))
    agent_id = setting_params['agentId']
    machine_group_id = ''
    try:
      #Back compat
      if(setting_params.has_key('machineGroupId')):
        machine_group_id = setting_params['machineGroupId']
      else:
        machine_group_name = setting_params['machineGroupName']
        method = httplib.HTTPSConnection
        if(vsts_url.startswith('http://')):
          vsts_url = vsts_url[7:]
          method = httplib.HTTPConnection
        elif(vsts_url.startswith('https://')):
          vsts_url = vsts_url[8:]
        basic_auth = '{0}:{1}'.format('', pat_token)
        basic_auth = base64.b64encode(basic_auth)
        headers = {
          'Authorization' : 'Basic {0}'.format(basic_auth)
        }
        machine_groups_address = Constants.machine_groups_address_format.format(project_name)
        conn = method(vsts_url)
        conn.request('GET', machine_groups_address, headers = headers)
        response = conn.getresponse()
        if(response.status == 200):
          val = {}
          response_string = response.read()
          val = json.loads(response_string)
          for i in range(0, val['count']):
            each_machine_group = val['value'][i]
            if(each_machine_group != None and each_machine_group['name'] == machine_group_name):
              machine_group_id = each_machine_group['id']
              break
    except Exception as e:
      pass
    if(agent_id == '' or machine_group_id == ''):
      raise Exception('Unable to get the machine group id or agent id. Ensure that the agent is configured before adding tags.'.format(working_folder))
    add_tags_to_agent(vsts_url, pat_token, project_name, machine_group_id, agent_id, tags_string)
    return Constants.return_success 
  except Exception as e:
    write_add_tags_log(e.message)
    raise e

def configure_agent_internal(vsts_url, pat_token, project_name, machine_group_name, agent_name, working_folder):
  global agent_listener_path, agent_service_path
  get_agent_listener_path(working_folder)
  get_agent_service_path(working_folder)
  configure_command = Constants.configure_agent_command.format(agent_listener_path, vsts_url, pat_token, agent_name, Constants.default_agent_work_dir, project_name, machine_group_name)
  config_agent_proc = subprocess.Popen(configure_command.split(' '), stdout = subprocess.PIPE, stderr = subprocess.PIPE)
  std_out, std_err = config_agent_proc.communicate()
  return_code = config_agent_proc.returncode
  write_configuration_log('Configure Agent Process exit code : {0}'.format(return_code))
  write_configuration_log('stdout : {0}'.format(std_out))
  write_configuration_log('srderr : {0}'.format(std_err))
  if(not (return_code == 0)):
    raise Exception('Agent configuration failed with error : {0}'.format(std_err))
  install_command = Constants.service_install_command.format(agent_service_path)
  write_configuration_log('Service install command is {0}'.format(install_command))
  install_service_proc = subprocess.Popen(install_command.split(' '), stdout = subprocess.PIPE, stderr = subprocess.PIPE, cwd = working_folder)
  std_out, std_err = install_service_proc.communicate()
  return_code = install_service_proc.returncode
  write_configuration_log('Service Installation process exit code : {0}'.format(return_code))
  write_configuration_log('stdout : {0}'.format(std_out))
  write_configuration_log('srderr : {0}'.format(std_err))
  if(not (return_code == 0)):
    raise Exception('Service installation failed with error : {0}'.format(std_err))
  start_command = Constants.service_start_command.format(agent_service_path)
  write_configuration_log('Service start command is {0}'.format(start_command))
  start_service_proc = subprocess.Popen(start_command.split(' '), stdout = subprocess.PIPE, stderr = subprocess.PIPE, cwd = working_folder)
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
    if(not agent_listener_exists(working_folder)):
      raise Exception('Unable to find the agent listener, ensure to download the agent before configuring.')
    if(agent_name is None or agent_name == ''):
      agent_name = platform.node() + '-MG'
      write_configuration_log('Agent name not provided, agent name will be set as ' + agent_name)
    write_configuration_log('Configuring agent')
    configure_agent_internal(vsts_url, pat_token, project_name, machine_group_name, agent_name, working_folder)
    return Constants.return_success
  except Exception as e:
    write_configuration_log(e.message)
    raise e



