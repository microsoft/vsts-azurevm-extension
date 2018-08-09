import urllib
import tarfile
import json
import Constants
import os
import platform
import Utils.HandlerUtil as Util

log_function = None

def set_logger(log_func):
  global log_function
  log_function = log_func

def raise_if_folder_contains_configured_agent(folder_name):
  for dirpath, dirnames, filenames in os.walk(folder_name):
    if '.agent' in filenames:
      raise Exception('One or more agents are already configured at {0}.\
      Unconfigure all the agents from the directory and all its subdirectories and then try again.'.format(folder_name))

def download_deployment_agent(vsts_url, user_name, pat_token, working_folder):
  if(user_name is None):
    user_name = ''
  _write_download_log('Getting the url for downloading the agent')
  agent_download_url = _get_agent_download_url(vsts_url, user_name, pat_token)
  _write_download_log('url for downloading the agent is {0}'.format(agent_download_url))
  _write_download_log('Getting the target tar gz file path')
  agent_target_file_path = os.path.join(working_folder, Constants.agent_target_name)
  raise_if_folder_contains_configured_agent(working_folder)
  Util.empty_dir(working_folder)
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

def _get_legacy_platform_key():
  info = platform.linux_distribution()
  os_distr_name = info[0]
  if(os_distr_name == Constants.red_hat_distr_name):
    os_distr_name = 'rhel'
  elif(os_distr_name == Constants.ubuntu_distr_name):
    os_distr_name = 'ubuntu'
  version_no = info[1].split('.')[0]
  sub_version = info[1].split('.')[1]
  legacy_platform_key = '{0}.{1}.{2}-{3}'.format(os_distr_name, version_no, sub_version, 'x64')
  return legacy_platform_key

def _get_agent_package_data(package_data_url, legacy_package_data_url, user_name, pat_token):
  _write_download_log('\t\tFetching Agent PackageData using {0}'.format(package_data_url))
  response = Util.make_http_call(package_data_url, 'GET', None, None, pat_token)
  if(response.status == 200):
    val = json.loads(response.read())
    if(len(val['value']) > 0):
      return val['value'][0]['downloadUrl']
    else:
      # Back compat for package addresses
      _write_download_log('\t\tFetching Agent PackageData using {0}'.format(legacy_package_data_url))
      _write_download_log('\t\t Making HTTP request for legacy package data')
      response = Util.make_http_call(legacy_package_data_url, 'GET', None, None, pat_token)
      if(response.status == 200):
        val = json.loads(response.read())
        return val['value'][0]['downloadUrl']
  raise Exception('Error while downloading VSTS agent. Please make sure that you enter the correct VSTS account name and PAT token.')

def _get_agent_download_url(vsts_url, user_name, pat_token):
  package_data_address_format = '/_apis/distributedtask/packages/agent/{0}?top=1&api-version={1}'
  package_data_url = vsts_url + package_data_address_format.format(Constants.platform_key, Constants.download_api_version)
  legacy_platform_key = _get_legacy_platform_key()
  legacy_package_data_url = vsts_url + package_data_address_format.format(legacy_platform_key, Constants.download_api_version)
  package_data = _get_agent_package_data(package_data_url, legacy_package_data_url, user_name, pat_token)
  return package_data

def _download_deployment_agent_internal(agent_download_url, target):
  if(os.path.isfile(target)):
    _write_download_log('\t\t {0} already exists, deleting it'.format(target))
    os.remove(target)
  _write_download_log('\t\t Starting Deployment Agent download')
  urllib.urlretrieve(agent_download_url, target)
  _write_download_log('\t\t Deployment Agent download done')

def _extract_target(target_file, target):
  tf = tarfile.open(target_file, 'r:gz')
  tf.extractall(target)
