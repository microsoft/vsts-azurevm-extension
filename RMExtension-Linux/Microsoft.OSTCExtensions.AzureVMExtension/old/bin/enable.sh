#!/bin/bash

#ErrorActionPreference='stop'
#Set-StrictMode -Version latest

if [ -z "$PSScriptRoot" ];
then 
	PSScriptRoot=`pwd`;
fi

RMExtHandler='/RMExtensionHandler.sh'
AzureExtHandler='/AzureExtensionHandler.sh'
source $PSScriptRoot$RMExtHandler
source $PSScriptRoot$AzureExtHandler

Start-RMExtensionHandler
DownloadVSTSAgent


