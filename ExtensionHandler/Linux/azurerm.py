#!/usr/bin/python

import sys
from Utils.WAAgentUtil import waagent
import Utils.HandlerUtil as Util
import Utils.RMExtensionStatus as RMExtensionStatus

def start_rm_extension_handler(operation):
  version_info = sys.version_info
  major = version_info[0]
  minor = version_info[1]
  
  if(major < 2 or (major == 2 and minor <6)):
    waagent.Log("Raising Value Error.")
    raise ValueError("Installed Python version is %d.%d. Minimum required version is 2.6."%(major, minor))
  handler_utility.do_parse_context(operation)
  clear_status_file()
  handler_utility.set_handler_status(code = RMExtensionStatus.rm_extension_status['Installing']['Code'], status = 'Installing',  message = RMExtensionStatus.rm_extension_status['Installing']['Message'])
  handler_utility.set_handler_status(ss_code = RMExtensionStatus.rm_extension_status['Initialized']['Code'], sub_status = 'Initialized', sub_status_message = RMExtensionStatus.rm_extension_status['Initialized']['Message'], operation = RMExtensionStatus.rm_extension_status['Initialized']['operationName'])

def enable():
  input_operation = 'enable'
  start_rm_extension_handler(input_operation)

def main():
  global handler_utility
  waagent.LoggerInit('/var/log/waagent.log','/dev/stdout')
  waagent.Log("Azure RM extension started to handle.")
  handler_utility = Util.HandlerUtility(waagent.Log, waagent.Error)
  if(len(sys.argv) == 3):
    if(sys.argv[2] == '-enable'):
      enable()
    else:
      raise ValueError("Invalid input operation. Valid operations are \'enable\'")

if(__name__ == '__main__'):
  main()

