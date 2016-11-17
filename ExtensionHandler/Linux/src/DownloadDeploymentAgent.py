import base64
import httplib
import urllib
import tarfile
import json
import Constants
import os

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


def construct_package_data_address(vsts_url, platform):
  package_data_address = Constants.package_data_address_format.format(platform, Constants.download_api_version)
  write_download_log('\t\t Package data adderss' + package_data_address)
  return package_data_address

def get_agent_package_data(vsts_url, package_data_address, user_name, pat_token):
  write_download_log('\t\t Forming the header for making HTTP request call')
  method = httplib.HTTPSConnection
  if(vsts_url.startswith('http://')):
    vsts_url = vsts_url[7:]
    method = httplib.HTTPConnection
  elif(vsts_url.startswith('https://')):
    vsts_url = vsts_url[8:]
  basic_auth = '{0}:{1}'.format(user_name, pat_token)
  #Todo Shlold be converted to byte array? unicode?
  basic_auth = base64.b64encode(basic_auth)
  headers = {
              'Authorization' : 'Basic {0}'.format(basic_auth)
            }
  write_download_log('\t\t Making HTTP request for package data')
  conn = method(vsts_url)
  conn.request('GET', package_data_address, headers = headers)
  response = conn.getresponse()
  #Should response be json parsd?
  if(response.status == 200):
    val = json.loads(response.read())
    return val['value'][0]['downloadUrl']
  else:
    raise Exception(response.read())

def get_agent_download_url(vsts_url, platform, user_name, pat_token):
  package_data_address = construct_package_data_address(vsts_url, platform)
  write_download_log('\t\tFetching Agent PackageData using (0)'.format(package_data_address))
  package_data = get_agent_package_data(vsts_url, package_data_address, user_name, pat_token)
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

def download_deployment_agent(vsts_url, user_name, pat_token, platform, working_folder, log_func):
  global log_function
  log_function = log_func
  if(user_name is None or user_name == ''):
    user_name = ' '
    write_download_log('No user name provided.')
  write_download_log('Getting the url for downloading the agent')
  agent_download_url = get_agent_download_url(vsts_url, platform, user_name, pat_token)
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

