#!/usr/bin/python

import string
from time import gmtime
import json
import subprocess
import Log
import os
from Utils.WAAgentUtil import waagent
import Utils.HandlerUtil as Util

waagent.LoggerInit('/var/log/waagent.log','/dev/stdout')
waagent.Log(" started to handle." )

handlerUtility = Util.HandlerUtility(waagent.Log, waagent.Error)
#handlerUtility.do_parse_context(operation)



ErrorActionPreference = 'stop'

#if (not(PSScriptRoot in locals() or PSScriptRoot in globals() or not(PSScript == None))) {
#        PSScriptRoot = os.path.dirname(os.path.abspath(__file__))
#}



#Circular buffer with methods
"""class CircularBuffer():
        self.buf = []
        self.total = 0

        def NewCircularBuffer(self, size):
                for f in range(size):
                        self.buf.append[""]

        def Push(self, value):
                self.buf[self.total++ % len(self.buf)] = value

        def Get(self, i):
                return self.buf[i]

        def Clear(self) {
                self.total = 0
        }

#Buffers for logs and substatus
extensionSubStatusBuffer = CircularBuffer()
extensionSubStatusBuffer.NewCircularBuffer(40)

extensionLogBuffer = CircularBuffer()
extensionLogBuffer.NewCircularBuffer(1000)
"""

logFilePath = ""

"""def clearHandlerSubStatusMessage():
	global extensionSubStatusBuffer
	extensionSubStatusBuffer = CircularBuffer()
	extensionSubStatusBuffer.NewCircularBuffer(40)
"""
#Handler cache with initialization
class HandlerCache():
	getHandlerEnvironment = None
	getHandlerExecutionSequenceNumber = None
	getHandlerSettings = None

handlerCache = HandlerCache()

def ClearHandlerCache():
	global handlerCache
	handlerCache.getHandlerEnvironment = None
	handlerCache.getHandlerExecutionSequenceNumber = None
	handlerCache.getHandlerSettings = None

#Clear-HandlerCache



def AddHandlerSubStatusMessage(message):
	statusFile = '{0}/{1}.status'.format(handlerUtility._context._status_dir, handlerUtility._context._seq_no)
	print "status file\n\n"
	print statusFile
	print '\n\ndone'
	timeStampUTC = gmtime()
	if(os.path.isfile(statusFile)):
		with open(statusFile, 'r') as fp :
			json.load(fp)
		statusList = json.loads(statusFile)
		statusObject = statusList[0]
		statusObject['timestampUTC'] = timestampUTC
		statusObject['status']['configurationAppliedTime'] = timestampUTC
		subStatusObject = statusObject['status']['subStatus'][0]
		#status = statusObject['status']
		#subStatus = subStatusObject['status']
		#code = subStatusObject['code']
		#name = subStatusObject['name']
		ssMessage = subStatusObject['formattedMessage']
		ssMessage['message'] = ssMessage + message
		
		with open(statusFile, 'w') as fp :
                	json.dump(statusList, fp)
	else:
		statusList = [{
				'status' : {
						'formattedMessage' : {
									'message' : '',
									'lang' : 'en-US'
								},
						'status' : '',
						'code' : '',
						'configurationAppliedTime' : timeStampUTC,
						'subStatus' : {
								'name' : 'RMExtensionLog',
								'status' : '',
								'code' : '',
								'formattedMesage' : {
										'lang' : 'en-US',
										'message' : message
								}
							}
				},
				'version' : '1.0',
				'timeStampUTC' : timeStampUTC
				}]
		with open(statusFile, 'w') as fp :
                        json.dump(statusList, fp)
	#SetHandlerStatus(code, message, status, subStatus)

"""
def AddHandlerSubStatusMessage(message):
	global extensionSubStatusBuffer
        extensionSubStatusBuffer.Push(message)

def GetHandlerEnvironment(Refresh):
	if (handlerCache.getHandlerEnvironment == None or Refresh == True) {
		handlerEnvironmentFile = PSScriptRoot+"\..\HandlerEnvironment.json"
	}
	#print("Inside GetandlerEnvironment")
	handlerEnvironmentFileContent = None
       for (sleepPeriod = 1; sleepPeriod < 64; sleepPeriod = 2 * sleepPeriod) {
            try
            {
                #handlerEnvironmentFileContent = Get-JsonContent handlerEnvironmentFile
                with open(handlerEnvironmentFile) as he_File
			data = json.load(he_File)
			os.write(he_File, data)
			os.close(he_File)
		if (os.stat(handlerEnvironmentFileContent).st_size == 0) {
                    throw handlerEnvironmentFile + " is empty"
                }
                break
            }
            except 
            {	#to do $_
                #Write-Log "Error reading handler environment (will retry): $_"
                time.sleep(sleepPeriod)
            }
        }
        if (os.stat(handlerEnvironmentFileContent).st_size == 0) {
            throw "Error initializing the extension: Cannot read $handlerEnvironmentFile"#        }
        handlerCache.getHandlerEnvironment = handlerEnvironmentFileContent[0].handlerEnvironment
    }
    return handlerCache.getHandlerEnvironment	

def GetHandlerExecutionSequenceNumber(Refresh):
    if (handlerCache.getHandlerExecutionSequenceNumber == None or Refresh == True)
    {
        handlerEnvironment = GetHandlerEnvironment(Refresh)
        settingsFilePattern = handlerEnvironment.configFolder + '/*.settings'
        proc = subprocess.Popen('ls '+settingsFilePattern, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
	settingsFiles,err = proc.communicate()
        if (os.stat(settingsFiles).st_zize == 0)
	settingsFiles,err = proc.communicate()
        if (os.stat(settingsFiles).st_zize == 0)
        {
            throw "Did not find any files that match $settingsFilePattern"
        }
        #to do sed/awk command
	#handlerCache.getHandlerExecutionSequenceNumber = print settingsFiles | foreach { [int] $_.BaseName } | sort -Descending | select -First 1
    }
    return handlerCache.getHandlerExecutionSequenceNumber

def GetHandlerExecutionSequenceNumber(){
	print("Inside GetHandlerExecutionSequenceNumber")
"""

def ClearStatusFile():
	statusFile = '{0}/{1}.status'.format(GetHandlerEnvironment.statusFolder, GetHandlerExecutionSequenceNumber)
	Write-Log("Clearing status file " + statusFile)
	open(statusFile, 'w').close()

def InitializeExtensionLogFile():
	waagent.LoggerInit('/var/log/waagent.log','/dev/stdout')

"""
def GetHandlerSettings(Refresh):
	if (script:handlerCache.getHandlerSettings == None or Refresh == True)
    	{
        	handlerEnvironment = GetHandlerEnvironment(Refresh)
        	sequenceNumber = GetHandlerExecutionSequenceNumber(Refresh)
        	handlerSettingsFile = '{0}\{1}.settings'.format($handlerEnvironment.configFolder, $sequenceNumber)
       		WriteLog "Reading handler settings from $handlerSettingsFile"
        	$settings = (Get-JsonContent $handlerSettingsFile).runtimeSettings[0].handlerSettings 
        	$settings['sequenceNumber'] = $sequenceNumber
        	#
        	# Visual Studio calls the extension without protected settings; add them here if needed
        	#
        	if (!($settings.ContainsKey('protectedSettings')))
        	{	
            		$settings['protectedSettings'] = ''
        	}
        	if (!($settings.ContainsKey('protectedSettingsCertThumbprint')))
        	{
            	$settings['protectedSettingsCertThumbprint'] = ''
        	}
        	#
        	# If the protected settings are present then decrypt them and override them with the decrypted value
        	#
        	if ($settings.protectedSettings)
        	{
            		$protectedSettings = $settings.protectedSettings
            		if (Get-IsAwsVm) {
                	WriteLog("Found protected settings on AWS VM. Decrypting through the AWS Key Management Service.")
                	$decryptedProtectedSettings = Invoke-DecryptAWSProtectedSettings -EncryptedProtectedSettings $protectedSettings
            		}
            		else {
                		Write-Log "Found protected settings on Azure VM. Decrypting with certificate."
                		$thumbprint = $settings.protectedSettingsCertThumbprint
                		$certificate = Get-ChildItem "Cert:\LocalMachine\My\$thumbprint" -ErrorAction SilentlyContinue
                		if (!$certificate)
                		{
                			throw 'Cannot find the encryption certificate for protected settings'
                		}
                		Add-Type -AssemblyName System.Security
                		$envelope = New-Object System.Security.Cryptography.Pkcs.EnvelopedCms
                		$envelope.Decode([Convert]::FromBase64String($protectedSettings))
                		$certificateCollection = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2Collection($certificate)
                		$envelope.Decrypt($certificateCollection)
                		$decryptedProtectedSettings = [System.Text.Encoding]::UTF8.GetString($envelope.ContentInfo.Content)
            		}    
            		settings.protectedSettings = ConvertTo-HashtableFromJson $decryptedProtectedSettings
        	}
        	handlerCache.getHandlerSettings = $settings
    }
    return handlerCache.getHandlerSettings
"""



def SetHandlerStatus(code, message, status = 'transitioning', subStatus = 'success'):
	statusFile = '{0}/{1}.status'.format(handlerUtility._context._status_dir, handlerUtility._context._seq_no)
	handlerUtility.log("Settings handler status to '{0}' ({1})".format(status, message))
	#to do correctr time, correct time format
	timeStampUTC = gmtime()
	if(os.path.isfile(statusFile)):
		with open(statusFile, 'r') as fp :
			statusList = json.load(fp)
		statusObject = statusList[0]
		subStatusObject = statusObject['status']['subStatus'][0]
		ssFormattedObj = subStatusObject['formattedMessage']
		ssFormattedObj['message'] = ssFormattedObject + message	
		statusObject['status']['status'] = status
		statusObject['timeStampUTC'] = timestampUTC
		statusObject['status']['configurationAppliedTime'] = timestampUTC
		subasatatusObject['status'] = subStatus
		with open(statusFile, 'w') as fp :
                	json.dump(statusList, fp)
	else:
		statusList = [{
                                'status' : {
                                                'formattedMessage' : {
                                                                        'message' : message,
                                                                        'lang' : 'en-US'
                                                                },
                                                'status' : status,
                                                'code' : code,
                                                'configurationAppliedTime' : timeStampUTC
                                                #'subStatus' : {
                                                #                'name' : 'RMExtensionLog',
                                                #                'status' : '',
                                                #                'code' : '',
                                                #                'formattedMesage' : {
                                                #                                'lang' : 'en-US',
                                                #                                'message' : message
                                                #                }
                                                #        }
                                },
                                'version' : '1.0',
                                'timeStampUTC' : timeStampUTC
                                }]

		with open(statusFile, 'w') as fp :
                	json.dump(statusList, fp)
