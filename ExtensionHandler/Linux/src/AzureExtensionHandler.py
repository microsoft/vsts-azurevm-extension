#!/usr/bin/python

import string
import time
import json
import subprocess
import os
from Utils.WAAgentUtil import waagent
import Utils.HandlerUtil as Util
import sys
import RMExtensionStatus

handler_manifest_file = 'HandlerManifest.json'
handler_env_file = 'HandlerEnvironment.json'
date_time_format = "%Y-%m-%dT%H:%M:%SZ"


def clear_status_file():
  status_file = '{0}/{1}.status'.format(handler_utility._context._status_dir, handler_utility._context._seq_no)
  handler_utility.log("Clearing status file " + status_file)
  open(status_file, 'w').close()


def set_handler_status(code=None, message=None, status = None, operation = None, sub_status = None, ss_code = None, sub_status_message = None):
  status_file = '{0}/{1}.status'.format(handler_utility._context._status_dir, handler_utility._context._seq_no)
  #handlerUtility.log("Setting handler status to '{0}' ({1})".format(status, message))
  #to do correctr time, correct time format
  timestamp_utc = time.strftime(date_time_format, time.gmtime())
  if(os.path.isfile(status_file) and os.stat(status_file).st_size != 0):
    with open(status_file, 'r') as fp :
      status_list = json.load(fp)
      status_object = status_list[0]
      if(message != None):
        handler_utility.log("Setting handler message to '{0}'".format(message))
        status_object['message'] = message
      sub_status_object = status_object['status']['subStatus'][0]
      ss_formatted_obj = sub_status_object['formattedMessage']
      if(sub_status_message != None):
        ss_orig_msg = ss_formatted_obj['message']
        if(ss_orig_msg == None):
          ss_orig_msg = ''
        handler_utility.log("Appending sub status message to '{0}'".format(sub_status_message))
        ss_formatted_obj['message'] = ss_orig_msg + '\n' + sub_status_message	
      if(status != None):
        handler_utility.log("Setting handler status to '{0}'".format(status))
        status_object['status']['status'] = status
      if(code != None):
        handler_utility.log("Setting handler code to '{0}'".format(code))
        status_object['code'] = code
      status_object['timeStampUTC'] = timestamp_utc
      status_object['status']['configurationAppliedTime'] = timestamp_utc
      if(sub_status != None):
        handler_utility.log("Setting handler sub status to '{0}'".format(sub_status))
        sub_status_object['status'] = sub_status
      if(ss_code != None):
        handler_utility.log("Setting handler sub status code to '{0}'".format(ss_code))
        sub_status_object['oode'] = ss_code
      if(operation != None):
        handler_utility.log("Setting handler sub status name to '{0}'".format(operation))
        sub_status_object['name'] = operation
      with open(status_file, 'w') as fp :
        json.dump(status_list, fp)
  else:
    status_list = [{
    'status' : {
      'formattedMessage' : {
        'message' : message,
        'lang' : 'en-US'
        },
      'status' : status,
      'code' : code,
      'subStatus' : [{
        'name' : operation,
        'status' : status,
        'code' : code,
        'formattedMessage' : {
          'lang' : 'en-US',
          'message' : sub_status_message
          }
        }],
      'configurationAppliedTime' : timestamp_utc
      },
      'version' : '1.0',
      'timeStampUTC' : timestamp_utc
    }]

    with open(status_file, 'w') as fp :
      json.dump(status_list, fp)


def start_rm_extension_handler(operation):
  version_info = sys.version_info
  major = version_info[0]
  minor = version_info[1]
  #try:
  if(major < 2 or (major == 2 and minor <6)):
    raise ValueError("Installed Python version is %d.%d. Minimum required version is 2.6."%(major, minor))
  handler_utility.do_parse_context(operation)
  clear_status_file()
  set_handler_status(code = RMExtensionStatus.rm_extension_status['Installing']['Code'], message = RMExtensionStatus.rm_extension_status['Installing']['Message'])
  set_handler_status(ss_code = RMExtensionStatus.rm_extension_status['Initialized']['Code'], sub_status_message = RMExtensionStatus.rm_extension_status['Initialized']['Message'], operation = RMExtensionStatus.rm_extension_status['Initialized']['operationName'])
  set_handler_status(RMExtensionStatus.rm_extension_status['Initialized']['Code'], RMExtensionStatus.rm_extension_status['Initialized']['Message'])
  #except Exception as e:
  #SetHandlerErrorStatus(e, operationName = RMExtensionStatus.RMExtensionStatus['Initializing']['operationName'])
  #raise


def set_handler_error_status(e, operation_name):
  handler_utility.log(e.message)
  exception_dictionary = e.__dict__
  operation_name = exception_dictionary['operationName']
  if(exception_dictionary['fullyQualifiedErrorId'] == RMExtensionStatus.rm_terminating_error_id):
    error_code = exception_dictionary['Code']
  else:
    error_code = RMExtensionStatus.rm_extension_status['GenericError']
  if(errorCode == RMExtensionStatus.rm_extension_status['InstallError']):
    error_message = 'The RM Extension failed to install: {0}.More information about the failure can be found in the logs located under \'{1}\' on the VM.To retry install, please remove the extension from the VM first.'.format(e.message, handler_utility._context._lof_dir)
  elif(error_code == RMExtensionStatus.rm_extension_status['ArgumentError']):
    error_message = 'The RM Extension received an incorrect input: {0}.Please correct the input and retry executing the extension.'.format(e.message)
  else:
    error_message = 'The RM Extension failed to execute: {0}.More information about the failure can be found in the logs located under \'{1}\' on the VM.'.format(e.message, handler_utility._context._lof_dir)
  set_handler_status(code = error_code, message = error_message, operation = operation_name, sub_status = 'error')
  set_handler_status(ssCode = error_code, sub_status_message = error_message, status = 'error')


class IncorrectUsageError(Exception):
  def __init__(self):
    self.message = 'Incorrect Usage. Correct usage is \'python <filename> enable | disable | install | uninstall\''

def enable():
  input_operation = 'enable'
  start_rm_extension_handler(input_operation)
  #config = GetConfigurationFromSettings()
  #configuredAgentExists = TestAgentAlreadyExists(config)
  #if(not configuredAgentExists):
  #  GetAgent(config)
  #else:
  #  handlerUtility.log('Skipping agent download as a configured agent already exists.')
  #  SetHandlerStatus(ssCode = RMExtensionStatus['SkippingDownloadDeploymentAgent']['Code'], subStatusMessage = RMExtensionStatus['SkippingDownloadDeploymentAgent']['Message'], oeprationName = RMExtensionStatus['SkippingDownloadDeploymentAgent']['operationName'])
  #RegisterAgent(config, configuredAgentExists)
 

def main():
  try:
    global handler_utility
    if(len(sys.argv) != 2):
      raise IncorrectUsageError
    if(os.path.isfile(handler_manifest_file)):
      ext_short_name = ''
      with open(handler_manifest_file, 'r') as fp:
        manifest_obj = json.load(fp)
        ext_short_name = manifest_obj[0]['name']
        handler_manifest = manifest_obj[0]['handlerManifest']
        waagent.LoggerInit('/var/log/waagent.log','/dev/stdout')
        waagent.Log("%s started to handle."%(ext_short_name))
        handler_utility = Util.HandlerUtility(waagent.Log, waagent.Error)
        is_usage_correct = False
        for k,v in handler_manifest.iteritems():
          if('split' in dir(v)):
            list_args = v.split(' -')
            if(len(list_args) > 1):
              input_operation = sys.argv[1]
              if(list_args[1] == input_operation):
                var_operation = globals()[input_operation]
                var_operation()
                is_usage_correct = True
                break
        if(not is_usage_correct):
          raise IncorrectUsageError
  except IncorrectUsageError as e:
    print e.message
    raise

if(__name__ == '__main__'):
  main()
