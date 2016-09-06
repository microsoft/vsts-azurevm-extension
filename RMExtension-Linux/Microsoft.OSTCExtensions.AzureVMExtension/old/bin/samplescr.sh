#!/bin/bash

source globals.sh
arr[4]="abc"
arr[0]=6
arg1=$1
#echo $arg1
function f1 {
	var2="abc"
#	export variable
}

#${arr[2]}
#f1
#var1=""
var1=$((${arg1[2]}-1))
#echo $arg1
var2=$((arg1[0]))
#echo $var2
#echo $((arg1[@]))
echo ${[@]}
