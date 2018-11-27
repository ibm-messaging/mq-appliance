#!/bin/ksh
# *****************************************************************************
# Copyright (c) 2018 IBM Corporation and other Contributors.
# Author: Ashlin Joseph
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
# *****************************************************************************

################################################################################
## File Name: sampleREST01.sh                                                 ##
##                                                                            ##
##    An example script that uses the restHelperLibrary.sh as an example      ##
##  In this script, at first all the running queue managers are listed.       ##
##  Then for each queue manager required information is retrieved via MQRSC   ##
##  calls and queue manager dump. Then the script retrieves config data from  ##
##  the appliance.                                                            ##
##                                                                            ##
################################################################################

##  THE FOLLOWING VARIABLES MUST BE CHANGED TO SUIT YOUR APPLIANCE!

APPLIANCE_IP=
TOKEN_FILE=/tmp/token.cookie
REST_PORT=5554

#Appliance file path and directory to which exec config files will be added to
APPLIANCE_DIR=temporary
DIR_TO_USE=aj

#Directory to which logs are written to
LOG_DIR=logs
#Directory to which errors are written to, if any
ERROR_DIR=errors

#Removing logs dir
rm -rf $LOG_DIR

#Removing errors dir
rm -rf $ERROR_DIR

#Creating logs dir
mkdir -p $LOG_DIR

source ./restHelperLibrary.sh

#===============================================================================
# Show AUTHSERV component is set for a given queue manager
function listQueueManagers {
  controlName='listQueueManagers'
  REST_MQSC='DIS AUTHSERV ALL'
  ERROR_FILE_NAME=$controlName"_"$qmgr"_runmqscRest.json"
  runmqscRest
  echo $OUTPUT > $LOG_DIR/$controlName$qmgr.out
}

# Display AUTHREC for a given queue manager
function disAuthrec {
  echo "Display authrec for $qmgr"
  controlName='disAuthrec'
  REST_MQSC='DIS AUTHREC'
  ERROR_FILE_NAME=$controlName"_"$qmgr"_runmqscRest.json"
  runmqscRest
  echo $OUTPUT > $LOG_DIR/$controlName$qmgr.out
}

# Getting MQ config dump file
function getQmgrDump {
  echo "Get qmgr dump for $qmgr"
  controlName='getQmgrDump'

  #Setting the file content
  fileContent1="mqcli\ndmpmqcfg -m $qmgr -a -o 1line"

  #Setting the file postfix; in the putfile $qmgr name will be added to the filename
  FILE_POSTFIX=_Exec.config
  EXEC_FILE_NAME="$qmgr$FILE_POSTFIX"
  ERROR_FILE_NAME=$controlName"_"$qmgr"_putFile_ERROR.json"
  putFile

  #Executing the config file that was added
  ERROR_FILE_NAME=$controlName"_"$qmgr"_execFile_ERROR.json"
  execFile

  #Setting the path and filename to be executed in the appliance
  CONFIG_FILE_PATH=mqbackup
  CONFIG_FILE=$qmgr.cfg
  ERROR_FILE_NAME=$controlName"_getConfigFile_ERROR.json"
  getConfigFile

  echo "$OUTPUT" > $LOG_DIR/$controlName$qmgr.out
}

# Getting all user config from the appliance
function getMQApplianceUserConfig {
  echo "Get MQ Appliance User Config"
  controlName='getMQApplianceUserConfig'

  #Setting path and filename to the auto-user.cfg in the appliance
  CONFIG_FILE_PATH=config
  CONFIG_FILE=auto-user.cfg
  ERROR_FILE_NAME=$controlName"_getConfigFile_ERROR.json"
  getConfigFile
  echo "$OUTPUT" > $LOG_DIR/$controlName.out

}

#Control #9: Getting the aplpiance config file
function getMQApplianceConfig {
  echo "Get MQ Appliance Config"
  controlName='getMQApplianceConfig'

  #Setting path and filename to the autoconfig.cfg in the appliance
  CONFIG_FILE_PATH=config
  CONFIG_FILE=autoconfig.cfg
  ERROR_FILE_NAME=$controlName"_getConfigFile_ERROR.json"
  getConfigFile
  echo "$OUTPUT" > $LOG_DIR/$controlName.out
}

#===============================================================================
echo "Enter the username:"
read USERNAME
echo "Enter the password:"
stty -echo
read PASSWORD
stty echo

# Log in to the MQ REST API to create the token required for MQ object update (POST or DELETE) calls
curl -s -k https://$APPLIANCE_IP:$REST_PORT/ibmmq/rest/v1/login -X POST --data "{\"username\":\"$USERNAME\",\"password\":\"$PASSWORD\"}" -c $TOKEN_FILE

# Recreating the directory in the appliance to ensure it's clean
deleteDir
createDir

getQueueManagerNames
qmgrs=( $qmgrNames )

# For loop for all queue managers
for qmgr in "${qmgrs[@]}"
do
	listQueueManagers
  disAuthrec
  getQmgrDump
done

getMQApplianceUserConfig
getMQApplianceConfig

echo "Logging out from the appliance and deleting the security token file. "
curl -k https://$APPLIANCE_IP:$REST_PORT/ibmmq/rest/v1/login -X DELETE -H "ibm-mq-rest-csrf-token: value" -b $TOKEN_FILE -c $TOKEN_FILE
rm -rf $TOKEN_FILE
