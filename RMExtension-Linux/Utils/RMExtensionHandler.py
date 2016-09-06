#!/usr/bin/python	

import AzureExtensionHandler
import Log
import RMExtensionStatus
import subprocess

#ErrorActionPreference = 'stop'
#global StartRMExtensionHandler


def StartRMExtensionHandler(operation):
	AzureExtensionHandler.handlerUtility.do_parse_context(operation)
	
	AzureExtensionHandler.SetHandlerSubStatus(subStatusMessage = "RM Extension initialization start")
	AzureExtensionHandler.ClearStatusFile()
	AzureExtensionHandler.ClearHandlerCache()
	#AzureExtensionHandler.ClearHandlerSubStatusMessage()
	#AzureExtensionHandler.InitializeExtensionLogFile
	
	#AzureExtensionHandler.handlerUtility.do_parse_context(operation)

	AzureExtensionHandler.SetHandlerStatus(subStatusMessage = "RM Extension initialization complete")
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



