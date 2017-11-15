import base64
import httplib
import urllib
import tarfile
import json
import Constants
import os
import platform

log_function = None

def write_download_log(log_message):
  log = '[Download]: ' + log_message
  if(log_function is not None):
    log_function(log)

def empty_dir(dir_name):
  for dirpath, dirnames, filenames in os.walk(dir_name, topdown = False):
    for filename in filenames:
      os.remove(os.path.join(dirpath, filename))
    for dirname in dirnames:
      os.rmdir(os.path.join(dirpath, dirname))

def get_host_and_address(account_info, package_data_address):
  if(account_info.__class__.__name__ == 'list' and len(account_info) == 3):
    address = '/' + account_info[1] + '/' + account_info[2] + package_data_address
    return account_info[0], address
  raise Exception('VSTS url is invalid')

def get_legacy_platform_key():
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

def get_agent_package_data(account_info, package_data_address, legacy_package_data_address, user_name, pat_token):
  write_download_log('\t\t Forming the header for making HTTP request call')
  vsts_url, package_data_address = get_host_and_address(account_info, package_data_address)
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
  write_download_log('\t\t Making HTTP request for package data')
  conn = method(vsts_url)
  conn.request('GET', package_data_address, headers = headers)
  response = conn.getresponse()
  if(response.status == 200):
    val = json.loads(response.read())
    if(len(val['value']) > 0):
      return val['value'][0]['downloadUrl']
    else:
      # Back compat for package addresses
      write_download_log('\t\tFetching Agent PackageData using {0}'.format(legacy_package_data_address))
      write_download_log('\t\t Making HTTP request for legacy package data')
      dummy, package_data_address = get_host_and_address(account_info, legacy_package_data_address)
      conn = method(vsts_url)
      conn.request('GET', package_data_address, headers = headers)
      response = conn.getresponse()
      if(response.status == 200):
        val = json.loads(response.read())
        return val['value'][0]['downloadUrl']
  raise Exception('Error while downloading VSTS extension. Please make sure that you enter the correct VSTS account name and PAT token.')

def get_agent_download_url(account_info, user_name, pat_token):
  package_data_address_format = '/_apis/distributedtask/packages/agent/{0}?top=1&api-version={1}'
  package_data_address = package_data_address_format.format(Constants.platform_key, Constants.download_api_version)
  legacy_platform_key = get_legacy_platform_key()
  legacy_package_data_address = package_data_address_format.format(legacy_platform_key, Constants.download_api_version)
  write_download_log('\t\t Package data address' + package_data_address)
  write_download_log('\t\tFetching Agent PackageData using {0}'.format(package_data_address))
  package_data = get_agent_package_data(account_info, package_data_address, legacy_package_data_address, user_name, pat_token)
  write_download_log('Deployment Agent download url - {0}'.format(package_data))
  return package_data

def get_agent_target_path(working_folder, agent_target_name):
  empty_dir(working_folder)
  return os.path.join(working_folder, agent_target_name)

def download_deployment_agent_internal(agent_download_url, target):
  if(os.path.isfile(target)):
    write_download_log('\t\t {0} already exists, deleting it'.format(target))
    os.remove(target)
  write_download_log('\t\t Starting Deployment Agent download')
  urllib.urlretrieve(agent_download_url, target)
  write_download_log('\t\t Deployment Agent download done')

def extract_target(target_file, target):
  tf = tarfile.open(target_file, 'r:gz')
  tf.extractall(target)

def download_deployment_agent(account_info, user_name, pat_token, working_folder, log_func):
  global log_function
  log_function = log_func
  if(user_name is None or user_name == ''):
    user_name = ' '
    write_download_log('No user name provided.')
  write_download_log('Getting the url for downloading the agent')
  agent_download_url = get_agent_download_url(account_info, user_name, pat_token)
  write_download_log('url for downloading the agent is {0}'.format(agent_download_url))
  write_download_log('Getting the target tar gz file path')
  agent_target_file_path = get_agent_target_path(working_folder, Constants.agent_target_name)
  write_download_log('\t\t Deployment agent will be downloaded at {0}'.format(agent_target_file_path))
  download_deployment_agent_internal(agent_download_url, agent_target_file_path)
  write_download_log('Downloaded deployment agent')
  write_download_log('Extracting tar gz file {0} to {1}'.format(agent_target_file_path, working_folder))
  extract_target(agent_target_file_path, working_folder)
  write_download_log('Done dowloading deployment agent')
  return Constants.return_success

