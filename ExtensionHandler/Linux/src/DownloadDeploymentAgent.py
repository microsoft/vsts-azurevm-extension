import urllib.request, urllib.parse, urllib.error
import tarfile
import json
import Utils.Constants as Constants
import os
import platform
import shutil
import Utils.HandlerUtil as Util

log_function = None

def set_logger(log_func):
  global log_function
  log_function = log_func

def create_agent_working_folder(agent_working_folder):
  _write_download_log('Working folder for AzureDevOps agent: {0}'.format(agent_working_folder))
  if(not os.path.isdir(agent_working_folder)):
    _write_download_log('Working folder does not exist. Creating it...')
    os.makedirs(agent_working_folder, 0o700)

def clean_agent_folder(agent_working_folder):
  #todo
  _write_download_log("Trying to remove the agent folder")
  top_level_agent_file = "{0}/.agent".format(agent_working_folder)
  if(os.path.isdir(agent_working_folder)):
    if(os.path.isfile(top_level_agent_file)):
      os.remove(top_level_agent_file)
    for dirpath, dirnames, filenames in os.walk(agent_working_folder):
      if '.agent' in filenames:
        raise Exception('One or more agents are already configured at {0}.\
        Unconfigure all the agents from the directory and all its subdirectories and then try again.'.format(agent_working_folder))
    shutil.rmtree(agent_working_folder)

def download_deployment_agent(vsts_url, pat_token, working_folder):
  _write_download_log('Getting the url for downloading the agent')
  agent_download_url = _get_agent_download_url(vsts_url, pat_token)
  _write_download_log('url for downloading the agent is {0}'.format(agent_download_url))
  _write_download_log('Getting the target tar gz file path')
  agent_target_file_path = os.path.join(working_folder, Constants.agent_target_name)
  clean_agent_folder(working_folder)
  create_agent_working_folder(working_folder)
  _write_download_log('\t\t Deployment agent will be downloaded at {0}'.format(agent_target_file_path))
  _download_deployment_agent_internal(agent_download_url, agent_target_file_path)
  _write_download_log('Downloaded deployment agent')
  _write_download_log('Extracting tar gz file {0} to {1}'.format(agent_target_file_path, working_folder))
  _extract_target(agent_target_file_path, working_folder)
  _write_download_log('Done dowloading deployment agent')
  return Constants.return_success

def _write_download_log(log_message):
  log = '[Download]: ' + log_message
  if(log_function is not None):
    log_function(log)

def _get_agent_package_data(package_data_url, pat_token):
  _write_download_log('\t\tFetching Agent PackageData using {0}'.format(package_data_url))
  response = Util.make_http_request(package_data_url, 'GET', None, None, pat_token)
  if(response.status == 200):
    val = json.loads(str(response.read(), 'utf-8'))
    return val['value'][0]
  raise Exception('An error occured while downloading AzureDevOps agent.')

def _get_agent_download_url(vsts_url, pat_token):
  package_data_address_format = '/_apis/distributedtask/packages/agent/{0}?top=1&api-version={1}'
  package_data_url = vsts_url + package_data_address_format.format(Constants.platform_key, Constants.download_api_version)
  package_data = _get_agent_package_data(package_data_url, pat_token)
  return package_data['downloadUrl']

def _download_deployment_agent_internal(agent_download_url, target):
  if(os.path.isfile(target)):
    _write_download_log('\t\t {0} already exists, deleting it'.format(target))
    os.remove(target)
  _write_download_log('\t\t Starting Deployment Agent download')
  Util.url_retrieve(agent_download_url, target)
  _write_download_log('\t\t Deployment Agent download done')

def _extract_target(target_file, target):
  tf = tarfile.open(target_file, 'r:gz')
  tf.extractall(target)
