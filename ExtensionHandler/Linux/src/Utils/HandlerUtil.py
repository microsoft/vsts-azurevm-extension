#
# Handler library for Linux IaaS
#
# Copyright 2014 Microsoft Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


"""
JSON def:
HandlerEnvironment.json
[{
  "name": "ExampleHandlerLinux",
  "seqNo": "seqNo",
  "version": "1.0",
  "handlerEnvironment": {
    "logFolder": "<your log folder location>",
    "configFolder": "<your config folder location>",
    "statusFolder": "<your status folder location>",
    "heartbeatFile": "<your heartbeat file location>",
    
  }
}]

Example ./config/1.settings
"{"runtimeSettings":[{"handlerSettings":{"protectedSettingsCertThumbprint":"1BE9A13AA1321C7C515EF109746998BAB6D86FD1","protectedSettings":
"MIIByAYJKoZIhvcNAQcDoIIBuTCCAbUCAQAxggFxMIIBbQIBADBVMEExPzA9BgoJkiaJk/IsZAEZFi9XaW5kb3dzIEF6dXJlIFNlcnZpY2UgTWFuYWdlbWVudCBmb3IgR+nhc6VHQTQpCiiV2zANBgkqhkiG9w0BAQEFAASCAQCKr09QKMGhwYe+O4/a8td+vpB4eTR+BQso84cV5KCAnD6iUIMcSYTrn9aveY6v6ykRLEw8GRKfri2d6tvVDggUrBqDwIgzejGTlCstcMJItWa8Je8gHZVSDfoN80AEOTws9Fp+wNXAbSuMJNb8EnpkpvigAWU2v6pGLEFvSKC0MCjDTkjpjqciGMcbe/r85RG3Zo21HLl0xNOpjDs/qqikc/ri43Y76E/Xv1vBSHEGMFprPy/Hwo3PqZCnulcbVzNnaXN3qi/kxV897xGMPPC3IrO7Nc++AT9qRLFI0841JLcLTlnoVG1okPzK9w6ttksDQmKBSHt3mfYV+skqs+EOMDsGCSqGSIb3DQEHATAUBggqhkiG9w0DBwQITgu0Nu3iFPuAGD6/QzKdtrnCI5425fIUy7LtpXJGmpWDUA==","publicSettings":{"port":"3000"}}}]}"


Example HeartBeat
{
"version": 1.0,
    "heartbeat" : {
        "status": "ready",
        "code": 0,
        "Message": "Sample Handler running. Waiting for a new configuration from user."
    }
}
Example Status Report:
[{"version":"1.0","timestampUTC":"2014-05-29T04:20:13Z","status":{"name":"Chef Extension Handler","operation":"chef-client-run","status":"success","code":0,"formattedMessage":{"lang":"en-US","message":"Chef-client run success"}}}]

"""


import os
import os.path
import sys
import imp
import base64
import json
import time
import RMExtensionStatus
import platform

from xml.etree import ElementTree
from os.path import join
from WAAgentUtil import waagent
from waagent import LoggerInit

DateTimeFormat = "%Y-%m-%dT%H:%M:%SZ"

MANIFEST_XML = "manifest.xml"

class HandlerContext:
    def __init__(self,name):
        self._name = name
        self._version = '0.0'
        return

class HandlerUtility:
    def __init__(self, log, error, s_name=None, l_name=None, extension_version=None):
        self._log = log
        self._error = error

        if s_name is None or l_name is None or extension_version is None:
            (l_name, s_name, extension_version) = self._get_extension_info()

        self._short_name = s_name
        self._extension_version = extension_version
        self._log_prefix = '[%s-%s] ' % (l_name, extension_version)

    def get_extension_version(self):
        return self._extension_version
    
    def _get_log_prefix(self):
        return self._log_prefix

    def _get_extension_info(self):
        if os.path.isfile(MANIFEST_XML):
            return self._get_extension_info_manifest()

        ext_dir = os.path.basename(os.getcwd())
        (long_name, version) = ext_dir.split('-')
        short_name = long_name.split('.')[-1]

        return long_name, short_name, version

    def _get_extension_info_manifest(self):
        with open(MANIFEST_XML) as fh:
            doc = ElementTree.parse(fh)
            namespace = doc.find('{http://schemas.microsoft.com/windowsazure}ProviderNameSpace').text
            short_name = doc.find('{http://schemas.microsoft.com/windowsazure}Type').text
            version = doc.find('{http://schemas.microsoft.com/windowsazure}Version').text

            long_name = "%s.%s" % (namespace, short_name)
            return (long_name, short_name, version)

    def _get_current_seq_no(self, config_folder):
        seq_no = -1
        cur_seq_no = -1
        freshest_time = None
        for subdir, dirs, files in os.walk(config_folder):
            for file in files:
                try:
                    cur_seq_no = int(os.path.basename(file).split('.')[0])
                    if(freshest_time == None):
                        freshest_time = os.path.getmtime(join(config_folder,file))
                        seq_no = cur_seq_no
                    else:
                        current_file_m_time = os.path.getmtime(join(config_folder,file))
                        if(current_file_m_time > freshest_time):
                            freshest_time=current_file_m_time
                            seq_no = cur_seq_no
                except ValueError:
                    continue
        return seq_no

    def log(self, message):
        self._log(self._get_log_prefix() + message)

    def error(self, message):
        self._error(self._get_log_prefix() + message)

    def _parse_config(self, ctxt):
        config = None
        try:
            config=json.loads(ctxt)
        except:
            self.error('JSON exception decoding ' + ctxt)

        if config == None:
            self.error("JSON error processing settings file:" + ctxt)
        else:
            handlerSettings = config['runtimeSettings'][0]['handlerSettings']
            if handlerSettings.has_key('protectedSettings') and \
                    handlerSettings.has_key("protectedSettingsCertThumbprint") and \
                    handlerSettings['protectedSettings'] is not None and \
                    handlerSettings["protectedSettingsCertThumbprint"] is not None:
                protectedSettings = handlerSettings['protectedSettings']
                thumb=handlerSettings['protectedSettingsCertThumbprint']
                cert=waagent.LibDir+'/'+thumb+'.crt'
                pkey=waagent.LibDir+'/'+thumb+'.prv'
                waagent.SetFileContents('/tmp/kk', protectedSettings)
                cleartxt=None
                cleartxt=waagent.RunGetOutput("base64 -d /tmp/kk | openssl smime  -inform DER -decrypt -recip " +  cert + "  -inkey " + pkey )[1]
                os.remove("/tmp/kk")
                if cleartxt == None:
                    self.error("OpenSSh decode error using  thumbprint " + thumb )
                    do_exit(1,operation,'error','1', operation + ' Failed')
                jctxt=''
                try:
                    jctxt=json.loads(cleartxt)
                except:
                    self.error('JSON exception decoding ' + cleartxt)
                handlerSettings['protectedSettings']=jctxt
                self.log('Config decoded correctly.')
        return config

    def do_parse_context(self,operation):
        _context = self.try_parse_context()
        if not _context:
            self.do_exit(1,operation,'error','1', operation + ' Failed')
        return _context
            
    def try_parse_context(self):
        self._context = HandlerContext(self._short_name)
        handler_env=None
        config=None
        ctxt=None
        code=0
        # get the HandlerEnvironment.json. According to the extension handler spec, it is always in the ./ directory
        self.log('cwd is ' + os.path.realpath(os.path.curdir))
        handler_env_file='./HandlerEnvironment.json'
        if not os.path.isfile(handler_env_file):
            self.error("Unable to locate " + handler_env_file)
            return None
        ctxt = waagent.GetFileContents(handler_env_file)
        if ctxt == None :
            self.error("Unable to read " + handler_env_file)
        try:
            handler_env=json.loads(ctxt)
        except:
            pass
        if handler_env == None :
            self.log("JSON error processing " + handler_env_file)
            return None
        if type(handler_env) == list:
            handler_env = handler_env[0]

        self._context._name = handler_env['name']
        self._context._version = str(handler_env['version'])
        self._context._config_dir=handler_env['handlerEnvironment']['configFolder']
	self._context._log_dir= handler_env['handlerEnvironment']['logFolder']
        self._context._log_file= os.path.join(handler_env['handlerEnvironment']['logFolder'],'extension.log')
        self._change_log_file()
        self._context._status_dir=handler_env['handlerEnvironment']['statusFolder']
        self._context._heartbeat_file=handler_env['handlerEnvironment']['heartbeatFile']
        self._context._seq_no = self._get_current_seq_no(self._context._config_dir)
        if self._context._seq_no < 0:
            self.error("Unable to locate a .settings file!")
            return None
        self._context._seq_no = str(self._context._seq_no)
        self.log('sequence number is ' + self._context._seq_no)
        self._context._status_file= os.path.join(self._context._status_dir, self._context._seq_no +'.status')
        self._context._settings_file = os.path.join(self._context._config_dir, self._context._seq_no + '.settings')
        self.log("setting file path is" + self._context._settings_file)
        ctxt=None
        ctxt=waagent.GetFileContents(self._context._settings_file)
        if ctxt == None :
            error_msg = 'Unable to read ' + self._context._settings_file + '. '
            self.error(error_msg)
            return None

        self.log("JSON config: " + ctxt)
        self._context._config = self._parse_config(ctxt)
        return self._context


    def _change_log_file(self):
        self.log("Change log file to " + self._context._log_file)
        LoggerInit(self._context._log_file,'/dev/stdout')
        self._log = waagent.Log
        self._error = waagent.Error

    def set_verbose_log(self, verbose):
        if(verbose == "1" or verbose == 1):
            self.log("Enable verbose log")
            LoggerInit(self._context._log_file, '/dev/stdout', verbose=True)
        else:
            self.log("Disable verbose log")
            LoggerInit(self._context._log_file, '/dev/stdout', verbose=False)

    def is_seq_smaller(self):
        return int(self._context._seq_no) <= self._get_most_recent_seq()

    def save_seq(self):
        self._set_most_recent_seq(self._context._seq_no)
        self.log("set most recent sequence number to " + self._context._seq_no)

    def exit_if_enabled(self):
        self.exit_if_seq_smaller()

    def exit_if_seq_smaller(self):
        if(self.is_seq_smaller()):
            self.log("Current sequence number, " + self._context._seq_no + ", is not greater than the sequnce number of the most recent executed configuration. Exiting...")
            sys.exit(0)
        self.save_seq()

    def _get_most_recent_seq(self):
        if(os.path.isfile('mrseq')):
            seq = waagent.GetFileContents('mrseq')
            if(seq):
                return int(seq)

        return -1

    def is_current_config_seq_greater_inused(self):
        return int(self._context._seq_no) > self._get_most_recent_seq()

    def get_inused_config_seq(self):
        return self._get_most_recent_seq()

    def set_inused_config_seq(self,seq):
        self._set_most_recent_seq(seq)

    def _set_most_recent_seq(self,seq):
        waagent.SetFileContents('mrseq', str(seq))

    def do_status_report(self, operation, status, status_code, message):
        self.log("{0},{1},{2},{3}".format(operation, status, status_code, message))
        tstamp=time.strftime(DateTimeFormat, time.gmtime())
        stat = [{
            "version" : self._context._version,
            "timestampUTC" : tstamp,
            "status" : {
                "name" : self._context._name,
                "operation" : operation,
                "status" : status,
                "code" : status_code,
                "formattedMessage" : {
                    "lang" : "en-US",
                    "message" : message
                }
            }
        }]
        stat_rept = json.dumps(stat)
        if self._context._status_file:
            tmp = "%s.tmp" %(self._context._status_file)
            with open(tmp,'w+') as f:
                f.write(stat_rept)
            os.rename(tmp, self._context._status_file)

    def do_heartbeat_report(self, heartbeat_file,status,code,message):
        # heartbeat
        health_report='[{"version":"1.0","heartbeat":{"status":"' + status+ '","code":"'+ code + '","Message":"' + message + '"}}]'
        if waagent.SetFileContents(heartbeat_file,health_report) == None :
            self.error('Unable to wite heartbeat info to ' + heartbeat_file)

    def do_exit(self,exit_code,operation,status,code,message):
        try:
            self.do_status_report(operation, status,code,message)
        except Exception as e:
            self.log("Can't update status: "+str(e))
        sys.exit(exit_code)

    def get_name(self):
        return self._context._name
    
    def get_seq_no(self):
        return self._context._seq_no

    def get_log_dir(self):
        return self._context._log_dir

    def get_handler_settings(self):
        return self._context._config['runtimeSettings'][0]['handlerSettings']

    def get_protected_settings(self):
        return self.get_handler_settings().get('protectedSettings')

    def get_public_settings(self):
        return self.get_handler_settings().get('publicSettings')

    #By Tejas
    def clear_status_file(self):
        status_file = '{0}/{1}.status'.format(self._context._status_dir, self._context._seq_no)
        self.log("Clearing status file " + status_file)
        open(status_file, 'w').close()

    def set_handler_status(self, code=None, message=None, status = 'transitioning', operation_name = None, sub_status = 'success', ss_code = None, sub_status_message = None):
        status_file = '{0}/{1}.status'.format(self._context._status_dir, self._context._seq_no)
        #handlerUtility.log("Setting handler status to '{0}' ({1})".format(status, message))
        #to do correctr time, correct time format
        timestamp_utc = time.strftime(DateTimeFormat, time.gmtime())
        if(os.path.isfile(status_file) and os.stat(status_file).st_size != 0):
            status_file_contents = waagent.GetFileContents(status_file)
            status_list = json.loads(status_file_contents)
            status_object = status_list[0]
            sub_status_list = status_object['status']['subStatus']
            if(code != None):
                self.log("Setting handler message to '{0}'".format(message))
                status_object['message'] = message
                self.log("Setting handler status to '{0}'".format(status))
                status_object['status']['status'] = status
                self.log("Setting handler code to '{0}'".format(code))
                status_object['code'] = code
                status_object['timeStampUTC'] = timestamp_utc
                status_object['status']['configurationAppliedTime'] = timestamp_utc
            elif(ss_code != None):
                self.log("Appending sub status")
                new_msg = {'lang' : 'eng-US', 'message' : sub_status_message}
                new_item = {'name' : operation_name, 'code' : ss_code, 'status' : sub_status, 'formattedMessage' : new_msg}
                sub_status_list.append(new_item)
        else:
            status_list = [{
                'status' : {
                    'formattedMessage' : {
                        'message' : message,
                        'lang' : 'en-US'
                    },
                    'status' : status,
                    'code' : code,
                    'subStatus' : [],
                    'configurationAppliedTime' : timestamp_utc
                },
                'version' : '1.0',
                'timeStampUTC' : timestamp_utc
            }]
            if(ss_code != None):
                self.log("Appending sub status")
                status_list['status']['subStatus'].append({'name' : operation_name, 'code' : ss_code, 'status' : sub_status, 'formattedMessage' : {'lang' : 'eng-US', 'message' : sub_status_message}})
        new_contents = json.dumps(status_list)
        waagent.SetFileContents(status_file, new_contents)

    def set_handler_error_status(self, e, operation_name):
        self.log(getattr(e,'message'))
        if(getattr(e,'ErrorId') == RMExtensionStatus.rm_terminating_error_id):
            error_code = getattr(e,'Code')
        else:
            error_code = RMExtensionStatus.rm_extension_status['GenericError']
        if(errorCode == RMExtensionStatus.rm_extension_status['InstallError']):
            error_message = 'The RM Extension failed to install: {0}.More information about the failure can be found in the logs located under \'{1}\' on the VM.To retry install, please remove the extension from the VM first.'.format(e.message, self._context._lof_dir)
        elif(error_code == RMExtensionStatus.rm_extension_status['ArgumentError']):
            error_message = 'The RM Extension received an incorrect input: {0}.Please correct the input and retry executing the extension.'.format(e.message)
        else:
            error_message = 'The RM Extension failed to execute: {0}.More information about the failure can be found in the logs located under \'{1}\' on the VM.'.format(e.message, self._context._lof_dir)
        set_handler_status(code = error_code, message = error_message, operation = operation_name, sub_status = 'error')
        set_handler_status(ssCode = error_code, sub_status_message = error_message, status = 'error')

    def get_os_version(self):
        value = platform.uname()[4]
        output = {'IsX64':value=='x86_64'}
        return output

    #def new_handler_terminating_error():

    def verify_input_not_null(self, input_key, input_value = None):
        if(input_value == None):
            message ='{0} should be specified'.format(input_key) 
            excep = RMExtensionStatus.new_handler_terminating_error(RMExtensionStatus.rm_extension_status['ArgumentError'], message)
            raise excep


