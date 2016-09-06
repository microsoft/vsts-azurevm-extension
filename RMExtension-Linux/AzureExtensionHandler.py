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


#Handler cache with initialization
"""
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
"""
#Clear-HandlerCache

"""
def AddHandlerSubStatusMessage(message):
	statusFile = '{0}/{1}.status'.format(handlerUtility._context._status_dir, handlerUtility._context._seq_no)
	timeStampUTC = gmtime()
	if(os.path.isfile(statusFile) and os.stat(statusFile).st_size != 0):
		with open(statusFile) as fp :
			statusList=json.load(fp)
		#statusList = json.loads(statusFile)
		statusObject = statusList[0]
		#statusObject['timestampUTC'] = timestampUTC
		#statusObject['status']['configurationAppliedTime'] = timestampUTC
		subStatusObject = statusObject['status']['subStatus'][0]
		#status = statusObject['status']
		#subStatus = subStatusObject['status']
		#code = subStatusObject['code']
		#name = subStatusObject['name']
		ssMessage = subStatusObject['formattedMessage']
		ssMessage['message'] = ssMessage['message'] + message
		
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
						#'configurationAppliedTime' : timeStampUTC,
						'subStatus' : [{
								'name' : 'RMExtensionLog',
								'status' : '',
								'code' : '',
								'formattedMessage' : {
										'lang' : 'en-US',
										'message' : message
								}
							}]
				},
				'version' : '1.0',
				#'timeStampUTC' : timeStampUTC
				}]
		with open(statusFile, 'w') as fp :
                        json.dump(statusList, fp)
	#SetHandlerStatus(code, message, status, subStatus)

"""

def ClearStatusFile():
	statusFile = '{0}/{1}.status'.format(handlerUtility._context._status_dir, handlerUtility._context._seq_no)
	handlerUtility.log("Clearing status file " + statusFile)
	open(statusFile, 'w').close()


def SetHandlerStatus(code = 0, message = '', status = 'transitioning', subStatus = 'success', subStatusMessage = ''):
	statusFile = '{0}/{1}.status'.format(handlerUtility._context._status_dir, handlerUtility._context._seq_no)
	handlerUtility.log("Settings handler status to '{0}' ({1})".format(status, message))
	#to do correctr time, correct time format
	timeStampUTC = gmtime()
	if(os.path.isfile(statusFile) and os.stat(statusFile).st_size != 0):
		with open(statusFile, 'r') as fp :
			statusList = json.load(fp)
		statusObject = statusList[0]
		statusObject['message'] = message
		subStatusObject = statusObject['status']['subStatus'][0]
		ssFormattedObj = subStatusObject['formattedMessage']
		ssFormattedObj['message'] = ssFormattedObj['message'] + subStatusMessage	
		statusObject['status']['status'] = status
		statusObject['code'] = code
		#statusObject['timeStampUTC'] = timestampUTC
		#statusObject['status']['configurationAppliedTime'] = timestampUTC
		subStatusObject['status'] = subStatus
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
						'subStatus' : [{
                                                                'name' : 'RMExtensionLog',
                                                                'status' : status,
                                                                'code' : code,
                                                                'formattedMessage' : {
                                                                                'lang' : 'en-US',
                                                                                'message' : subStatusMessage
                                                                }
                                                 }]

                                                #'configurationAppliedTime' : timeStampUTC
                                },
                                'version' : '1.0',
                                #'timeStampUTC' : timeStampUTC
                                }]

		with open(statusFile, 'w') as fp :
                	json.dump(statusList, fp)
