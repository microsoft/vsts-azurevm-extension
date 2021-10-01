import os
import subprocess
import json
import platform
import Utils_python2.Constants as Constants
import codecs
import Utils_python2.HandlerUtil as Util
from pwd import getpwnam
from urllib2 import quote
from Utils_python2.GlobalSettings import proxy_config

agent_listener_path = ''
agent_service_path = ''
log_function = None
setting_params = {}

def get_agent_setting(working_folder, key):
  global setting_params
  agent_setting_file_path = os.path.join(working_folder, Constants.agent_setting)
  if(setting_params == {}):
    setting_params = json.load(codecs.open(agent_setting_file_path, 'r', 'utf-8-sig'))
  return setting_params[key] if(setting_params.has_key(key)) else ''

def set_logger(log_func):
  global log_function
  log_function = log_func

def is_agent_configured(working_folder):
  try:
    _write_log('Checking if existing agent is running from {0}'.format(working_folder))
    agent_path = os.path.join(working_folder, Constants.agent_setting)
    agent_setting_file_exists = os.path.isfile(agent_path)
    _write_log('\t\t Agent setting file exists : {0}'.format(agent_setting_file_exists))
    return agent_setting_file_exists
  except Exception as e:
    _write_log(e.args[0])
    raise

def is_agent_configuration_required(vsts_url, pat_token, deployment_group_name, project_name, working_folder):
  global log_function, setting_params

  try:
    _write_log('AgentReConfigurationRequired check started.')

    existing_vsts_url = get_agent_setting(working_folder, 'serverUrl')
    existing_vsts_url = existing_vsts_url.strip('/')
    existing_collection = get_agent_setting(working_folder, 'collectionName')
    if(existing_collection != ''):
      existing_vsts_url += '/{0}'.format(existing_collection)

    existing_deployment_group_data = None
    try:
      existing_deployment_group_data = _get_deployment_group_data_from_setting(existing_vsts_url, pat_token)
    except Exception as e:
      _write_log('\t\t\t Unable to get the deployment group data - {0}'.format(e.args[0]))

    if(existing_deployment_group_data == None or existing_deployment_group_data == {}):
      _write_log("\t\t\t agent configuration required Return : True (Unable to get the deployment group data from existing agent settings)")
      return True

    vsts_url_for_configuration = existing_vsts_url if (vsts_url.lower().startswith(existing_vsts_url.lower())) else vsts_url
    _write_log('\t\t\t Agent configured with \t\t\t\t Agent needs to be configured with')
    _write_log('\t\t\t {0} \t\t\t\t {1}'.format(existing_vsts_url, vsts_url_for_configuration))
    _write_log('\t\t\t {0} \t\t\t\t {1}'.format(existing_deployment_group_data['project']['name'], project_name))
    _write_log('\t\t\t {0} \t\t\t\t {1}'.format(existing_deployment_group_data['name'], deployment_group_name))

    if(existing_vsts_url.lower() == vsts_url_for_configuration.lower() and \
           existing_deployment_group_data['name'].lower() == deployment_group_name.lower() and \
           existing_deployment_group_data['project']['name'].lower() == project_name.lower()):
      _write_log('\t\t\t test_agent_configuration_required : False') 
      return False

    _write_log('\t\t\t test_agent_configuration_required : True') 
    return True
  except Exception as e:
    _write_log(e.args[0])
    raise

def add_agent_tags(vsts_url, project_name, pat_token, working_folder, tags_string):
  try:
    _write_add_tags_log('Adding the tags for configured agent')

    agent_setting_file_path = os.path.join(working_folder, Constants.agent_setting)
    _write_add_tags_log('\t\t Agent setting path : {0}'.format(agent_setting_file_path))

    if(not(os.path.isfile(agent_setting_file_path))):
      raise Exception('Unable to find the .agent file {0}. Ensure that the agent is configured before adding tags.'.format(agent_setting_file_path))

    agent_id = get_agent_setting(working_folder, 'agentId')
    project_id = get_agent_setting(working_folder, 'projectId')
    deployment_group_id = get_agent_setting(working_folder, 'deploymentGroupId')
    
    if(agent_id == '' or project_id == '' or deployment_group_id == ''):
      raise Exception('Unable to get one or more of the project id, deployment group id, or the agent id. Ensure that the agent is configured before addding tags.')

    _add_tags_to_agent_internal(vsts_url, pat_token, project_id, deployment_group_id, agent_id, tags_string)
    return Constants.return_success 
  except Exception as e:
    _write_add_tags_log(e.args[0])
    raise

def remove_existing_agent(working_folder):
  try:
    global agent_listener_path, agent_service_path, setting_params
    _set_agent_listener_path(working_folder)
    _set_agent_service_path(working_folder) 

    service_stop_proc = subprocess.Popen('{0} stop'.format(agent_service_path).split(' '), stdout = subprocess.PIPE, stderr = subprocess.PIPE, cwd = working_folder)
    std_out, std_err = service_stop_proc.communicate()
    return_code = service_stop_proc.returncode

    _write_configuration_log('Service Stop process exit code : {0}'.format(return_code))
    _write_configuration_log('stdout : {0}'.format(std_out))
    _write_configuration_log('srderr : {0}'.format(std_err))

    if(not (return_code == 0)):
      raise Exception('Service stop failed with error : {0}'.format(std_err))

    service_uninstall_proc = subprocess.Popen('{0} uninstall'.format(agent_service_path).split(' '), stdout = subprocess.PIPE, stderr = subprocess.PIPE, cwd = working_folder)
    std_out, std_err = service_uninstall_proc.communicate()
    return_code = service_uninstall_proc.returncode

    _write_configuration_log('Service uninstall process exit code : {0}'.format(return_code))
    _write_configuration_log('stdout : {0}'.format(std_out))
    _write_configuration_log('srderr : {0}'.format(std_err))

    if(not (return_code == 0)):
      raise Exception('Service uninstall failed with error : {0}'.format(std_err))

  except Exception as e:
    _write_configuration_log(e.args[0])
    raise

def configure_agent(vsts_url, pat_token, project_name, deployment_group_name, configure_agent_as_username, agent_name, working_folder):
  global agent_listener_path
  global log_function
  try:
    if(not _agent_listener_exists(working_folder)):
      raise Exception('Unable to find the agent listener, ensure to download the agent before configuring.')

    if(agent_name is None or agent_name == ''):
      agent_name = platform.node() + '-DG'
      _write_configuration_log('Agent name not provided, agent name will be set as ' + agent_name)

    _write_configuration_log('Configuring agent')
    _configure_agent_internal(vsts_url, pat_token, project_name, deployment_group_name, configure_agent_as_username, agent_name, working_folder)
    return Constants.return_success
  except Exception as e:
    _write_configuration_log(e.args[0])
    raise

###### Private methods ####################

def _write_configuration_log(log_message):
  global log_function
  log = '[Configuration]: {}'.format(log_message)
  if(log_function is not None):
    log_function(log)

def _write_log(log_message):
  global log_function
  log = '[Agent Checker]: {0}'.format(log_message)
  if(log_function is not None):
    log_function(log)

def _write_add_tags_log(log_message):
  global log_function
  log = '[AddTags]: {0}'.format(log_message)
  if(log_function is not None):
    log_function(log)

def _get_deployment_group_data_from_setting(vsts_url, pat_token):
  global setting_params
  project_id = str(setting_params['projectId'])
  deployment_group_id = str(setting_params['deploymentGroupId'])
  _write_log('\t\t Project id, Deployment group id - {0}, {1}'.format(project_id, deployment_group_id))
  if(project_id != '' and deployment_group_id != ''):
    deployment_group_data_address = '/{0}/_apis/distributedtask/deploymentgroups/{1}?api-version={2}'.format(project_id, deployment_group_id, Constants.targets_api_version)
    deployment_group_data_url = vsts_url + deployment_group_data_address

    response = Util.make_http_request(deployment_group_data_url, 'GET', None, None, pat_token)
    if(response.status == Constants.HTTP_OK):
      val = json.loads(response.read())
      _write_log('\t\t Deployment group details fetched successfully')
      return val
  return {}

def _set_agent_listener_path(working_folder):
  global agent_listener_path
  if(agent_listener_path == ''):
    agent_listener_path = os.path.join(working_folder, Constants.agent_listener)

def _set_agent_service_path(working_folder):
  global agent_service_path
  if(agent_service_path == ''):
    agent_service_path = os.path.join(working_folder, Constants.agent_service)

def _agent_listener_exists(working_folder):
  _set_agent_listener_path(working_folder)
  _write_configuration_log('\t\t Agent listener file : {0}'.format(agent_listener_path))
  agent_listener_exists = os.path.isfile(agent_listener_path)
  _write_configuration_log('\t\t Agent listener file exists : {0}'.format(agent_listener_exists))
  return agent_listener_exists

def _apply_tags_to_agent(vsts_url, pat_token, project_id, deployment_group_id, agent_id, tags_string):
  tags_address = '/{0}/_apis/distributedtask/deploymentgroups/{1}/Targets?api-version={2}'.format(project_id, deployment_group_id, Constants.targets_api_version)
  tags_url = vsts_url + tags_address
  headers = {
              'Content-Type' : 'application/json'
            }
  request_body = json.dumps([{'id' : json.loads(agent_id), 'tags' : json.loads(tags_string), 'agent' : {'id' : json.loads(agent_id)}}])
  _write_add_tags_log('Add tags request body : {0}'.format(request_body))
  response = Util.make_http_request(tags_url, 'PATCH', request_body, headers, pat_token)
  if(response.status == Constants.HTTP_OK):
    _write_add_tags_log('Patch call for tags succeeded')
  else:
    raise Exception('Tags could not be added.')

def _add_tags_to_agent_internal(vsts_url, pat_token, project_id, deployment_group_id, agent_id, tags_string):
  target_address = '/{0}/_apis/distributedtask/deploymentgroups/{1}/Targets/{2}?api-version={3}'.format(project_id, deployment_group_id, agent_id, Constants.targets_api_version)
  target_url = vsts_url + target_address
  response = Util.make_http_request(target_url, 'GET', None, None, pat_token)
  if(response.status == Constants.HTTP_OK):
    val = {}
    response_string = response.read()
    val = json.loads(response_string)
    existing_tags = val['tags']
    tags = json.loads(tags_string)
    for x in tags:
      if(x.lower() not in map(lambda y:y.lower(), existing_tags)):
        existing_tags.append(x)
    tags = existing_tags
  else:
    raise Exception('Tags could not be added. Unable to fetch the existing tags or deployment group details: {0} {1}'.format(str(response.status), response.reason))
  _write_add_tags_log('Updating the tags for agent target - {0}'.format(agent_id))
  _apply_tags_to_agent(vsts_url, pat_token, project_id, deployment_group_id, json.dumps(agent_id), json.dumps(tags, ensure_ascii = False))

def _set_folder_owner(folder, username):
  user_info = getpwnam(username)
  u_id, g_id = user_info.pw_uid, user_info.pw_gid
  for dirpath, dirnames, filenames in os.walk(folder):
    os.chown(dirpath, u_id, g_id)
    for filename in filenames:
      os.chown(os.path.join(dirpath, filename), u_id, g_id)

def _configure_agent_internal(vsts_url, pat_token, project_name, deployment_group_name, configure_agent_as_username, agent_name, working_folder):
  global agent_listener_path, agent_service_path
  _set_agent_listener_path(working_folder)
  _set_agent_service_path(working_folder)

  config_url = vsts_url

  if(Constants.is_on_prem):
    config_url = vsts_url[0:vsts_url.rfind('/')]
    collection = vsts_url[vsts_url.rfind('/'):]

  configure_command_args = ['--url', config_url,
                            '--auth', 'PAT',
                            '--token', pat_token,
                            '--agent', agent_name,
                            '--work', Constants.default_agent_work_dir,
                            '--projectname', project_name,
                            '--deploymentgroupname', deployment_group_name]
  if(Constants.is_on_prem):
    configure_command_args += ['--collectionname', collection]
  
  if('ProxyUrl' in proxy_config):
    configure_command_args += ['--proxyurl', proxy_config['ProxyUrl']]

  config_agent_proc = subprocess.Popen('{0} configure --unattended --acceptteeeula --deploymentgroup --replace'.format(agent_listener_path).split(' ') + configure_command_args, stdout = subprocess.PIPE, stderr = subprocess.PIPE)
  std_out, std_err = config_agent_proc.communicate()
  return_code = config_agent_proc.returncode

  _write_configuration_log('Configure Agent Process exit code : {0}'.format(return_code))
  _write_configuration_log('stdout : {0}'.format(std_out))
  _write_configuration_log('srderr : {0}'.format(std_err))

  if(not (return_code == 0)):
    raise Exception('Agent configuration failed with error : {0}'.format(std_err))

  if(configure_agent_as_username == ''):
    configure_agent_as_username = 'root'

  _set_folder_owner(working_folder, configure_agent_as_username)

  install_command = '{0} install {1}'.format(agent_service_path, configure_agent_as_username)
  _write_configuration_log('Service install command is {0}'.format(install_command))
  install_service_proc = subprocess.Popen(install_command.split(' '), stdout = subprocess.PIPE, stderr = subprocess.PIPE, cwd = working_folder)
  std_out, std_err = install_service_proc.communicate()
  return_code = install_service_proc.returncode

  _write_configuration_log('Service Installation process exit code : {0}'.format(return_code))
  _write_configuration_log('stdout : {0}'.format(std_out))
  _write_configuration_log('srderr : {0}'.format(std_err))

  if(not (return_code == 0)):
    raise Exception('Service installation failed with error : {0}'.format(std_err))

  start_command = '{0} start'.format(agent_service_path)
  _write_configuration_log('Service start command is {0}'.format(start_command))
  start_service_proc = subprocess.Popen(start_command.split(' '), stdout = subprocess.PIPE, stderr = subprocess.PIPE, cwd = working_folder)
  std_out, std_err = start_service_proc.communicate()
  return_code = start_service_proc.returncode

  _write_configuration_log('Service start process exit code : {0}'.format(return_code))
  _write_configuration_log('stdout : {0}'.format(std_out))
  _write_configuration_log('srderr : {0}'.format(std_err))

  if(not (return_code == 0)):
    raise Exception('Service start failed with error : {0}'.format(std_err))
