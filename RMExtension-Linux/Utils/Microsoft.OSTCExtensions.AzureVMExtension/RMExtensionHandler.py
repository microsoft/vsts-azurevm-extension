#!/usr/bin/python	

import AzureExtensionHandler
import Log
import RMExtensionStatus
import subprocess

ErrorActionPreference = 'stop'
global StartRMExtensionHandler
#if (not(PSScriptRoot in locals() or PSScriptRoot in globals() or not(PSScript == None))) {
#        PSScriptRoot = os.path.dirname(os.path.abspath(__file__))
#}


#class CircularBuffer:
#	buf = []
#	total = 0

#	NewCircularBuffer(size):
#		for f in range(size):
#			buf.append[""]	

#	Push(value):
#		buf[total++ % len(buf)] = value
		
#	Get(i):
 #       	return buf[i]

#	Clear() {
#		total = 0
#	}

#extensionSubStatusBuffer = CircularBuffer()
#extensionSubStatusBuffer.NewCircularBuffer(40)

#extensionLogBuffer = CircularBuffer()
#extensionLogBuffer.NewCircularBuffer(1000)


#def AddHandlerSubStatusMessage(message):
#	extensionSubStatusBuffer.Push(message)
def StartRMExtensionHandler(operation):
	AzureExtensionHandler.handlerUtility.do_parse_context(operation)
	
	AzureExtensionHandler.AddHandlerSubStatusMessage("RM Extension initialization start")
	AzureExtensionHandler.ClearStatusFile()
	AzureExtensionHandler.ClearHandlerCache()
	#AzureExtensionHandler.ClearHandlerSubStatusMessage()
	#AzureExtensionHandler.InitializeExtensionLogFile
	
	#AzureExtensionHandler.handlerUtility.do_parse_context(operation)

	AzureExtensionHandler.AddHandlerSubStatusMessage("RM Extension initialization complete")
	AzureExtensionHandler.SetHandlerStatus(RMExtensionStatus.RMExtensionStatus['Initialized']['Code'], RMExtensionStatus.RMExtensionStatus['Initialized']['Message'])
	#print("Inside StartRMExtensionHandler")

"""
def DownloadVSTSAgent(operation):
	#todo add try catch
	AzureExtensionHandler.AddHandlerSubStatusessage("Download VSTS agent start")
	sequenceNumber = AzureExtensionHandler.GetHandlerExecutionSequenceNumber()
	Log.WriteLog("	Sequence Number	:	" + sequenceNumber)
	#Retrieve settings from file
	settings = AzureExtensionHandler.GetHandlerSettings()
	publicSettings = settings['publicSettings']
	if(publicSettings == None) {
		publicSettings = {}
	}
	Log.WriteLog("Done reading config settings from file...")
	AzureExtensionHandler.AddHandlerSubStatusessage("Done reading config settings from file")
	Log.WriteLog("Invoking script to download VSTS agent package...")
	#print("Inside DownloadVSTSAgent")
	#todo execution statement
	PSScriptRoot.
	AzureExtensionHandler.AddHandlerSubStatusessage("Download VSTS agent complete")
	AzureExtensionHandler.SetHandlerStatus(RMExtensionStatus.RMExtStat.DownloadedVSTSAgent.Code, RMExtensionStatus.RMExtStat.DownloadedVSTSAgent.Message)	Log.WriteLog("Done downloading VSTS agent package...")
"""



#global StartRMExtensionHandler
global DownloadVSTSAgent
