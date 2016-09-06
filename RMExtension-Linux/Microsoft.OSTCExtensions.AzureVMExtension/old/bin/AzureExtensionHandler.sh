#!bin/bash

#extensionSubStatusBuffer[40]=""
#extensionSubStatusBuffer[0]=0

#extensionLogBuffer[1000]=""
#extensionLogBuffer[0]=0

function Add-HandlerSubStatusMessage {
	echo "Inside Add-HandlerSubStatusMessage"
}

#push into buffer
#arguments : array, value
function Push {
	#source globals.sh
	arg1=$1
	arg2=$2
	#todo. chceck associativity
	var1=$(([arg1[1]++ - 2))
	var2=$((var1 % arg1[0]))
        ((arg1[var2 + 2]=$2))
}

#function Get {
#	arg1=$1
#	var1=$((arg1[1]))
#	var2=$((arg1[0]))
#        if [ $var1 -gt $var2 ]
#        then
#        	i=$this._total % $this._buffer.Length
#            	for ((count = 0; count -lt $this._buffer.Length; $count++)) {
#                	$this._buffer[$i++ % $this._buffer.Length] 
#        	}
#	else 
#            	for ($i = 0; $i -lt $this._total; $i++) {
#                	$this._buffer[$i]
#            	}
#     	fi
#}

#clear buffer
function Clear {
	arg1=$1
	${arg1[1]}=0
}

function Add-HandlerSubStatusMessage {    
    Push extensionLogBuffer
}
