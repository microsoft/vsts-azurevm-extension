#!/bin/bash

awk 'BEGIN{FPAT = "."} {} END{}' $1
