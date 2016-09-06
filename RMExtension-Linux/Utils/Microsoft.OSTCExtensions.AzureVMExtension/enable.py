#!/usr/bin/python

import os
import RMExtensionHandler
#from RMExtensionHandler import DownloadVSTSAgent
#ErrorActionPreference = 'stop'
#if 'PSScriptRoot' not in dir() or PSScriptRoot==None :
#	PSScriptRoot=os.path.dirname(os.path.realpath(__file__))
#print PSScriptRoot
RMExtensionHandler.StartRMExtensionHandler('enable')
#RMExtensionHandler.DownloadVSTSAgent('enable')
