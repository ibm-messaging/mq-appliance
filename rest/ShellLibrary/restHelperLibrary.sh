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
## File Name: restHelperLibrary.sh                                            ##
##                                                                            ##
##    This helper library is built around some of the MQ Appliance REST API   ##
##  to help MQ appliance users to easily built scripts that can be used to    ##
##  perform tasks in the appliance.                                           ##
##                                                                            ##
##  To use the helper library you need to import the helper library:          ##
##          source ./restHelperLibrary.#!/bin/sh                              ##
##                                                                            ##
##  This script is built using Curl and jq.                                   ##
##    Curl: https://curl.haxx.se/docs/manpage.html                            ##
##    jq: https://stedolan.github.io/jq/                                      ##
##                                                                            ##
################################################################################

# Fn returns the list of running qmgrs in a given appliance via the REST API
function getQueueManagerNames {

  #Curl command to get all qmgr names and status;
  output3=$(curl -s -u $USERNAME:$PASSWORD -k https://$APPLIANCE_IP:$REST_PORT/ibmmq/rest/v1/admin/qmgr -X GET)
  echo $output3 | jq '.qmgr[] | select(.state == "running") | .name' | tr -d \"  > logs/QueueManagers.json
  #Gets the names of the queue manager that are in "running" state
  qmgrNames=`echo $output3 | jq '.qmgr[] | select(.state == "running") | .name' | tr -d \" `

  #Error Handling: If the qmgr names returned is empty, something has gone wrong!
  if [[ `echo $qmgrNames` != "" ]]
  then
    echo "Queue managers running in $APPLIANCE_IP are: "
    echo $qmgrNames
  else
    mkdir -p $ERROR_DIR
    echo "ERROR: GET Queue Manager Names Command FAILED"
    echo "REST response written logged to $ERROR_DIR/GetQmgrsERROR.json"
    echo "$output3" > $ERROR_DIR/getQueueManagerNames.json
  fi
}

#Fn that runs a given RUNMQSC command via the REST API
function runmqscRest {
  #Curl command that runs RUNMQSC command and receive the response
  output3=$(curl -s -k https://$APPLIANCE_IP:$REST_PORT/ibmmq/rest/v1/admin/action/qmgr/$qmgr/mqsc -X POST -b $TOKEN_FILE -H "ibm-mq-rest-csrf-token: value" -H "Content-Type: application/json" --data "{\"type\":\"runCommand\",\"parameters\":{\"command\":\"$REST_MQSC\"}}" )
  #Error Handling: Ensuring the REST Call was made successfully
  if [[ `echo $output3 | jq '.overallCompletionCode'` == 0 ]]
  then
    echo "$REST_MQSC executed for $qmgr successfully"
  else
    mkdir -p $ERROR_DIR
    echo "ERROR: RUNMQSC COMMAND FAILED"
    echo REST response written logged to $ERROR_DIR/$ERROR_FILE_NAME
    echo $output3 > $ERROR_DIR/$ERROR_FILE_NAME
  fi

  #Getting the RUNMQSC response back to the control via variables set
  output2=`echo $output3 | jq '.commandResponse[].text'`
  #Adds the output from running RUNMQSC to a variable that can be used later
  OUTPUT=`echo "$output2" | sed -n 's/  */ /gp' | tr -d \"`

}

#Fn that creates a directory in the appliance via REST API
function createDir {
  #Curl command that creates the dir; requires certain variables to be set before running the fn
  output3=$(curl -s -k https://$APPLIANCE_IP:$REST_PORT/mgmt/filestore/default/$APPLIANCE_DIR -X POST -u $USERNAME:$PASSWORD -H "ibm-mq-rest-csrf-token: value" -H "Content-Type: application/json" --data "{\"directory\":{\"name\":\"$DIR_TO_USE\"}}" )

  #Error Handling: Ensuring the REST Call was made successfully
  if [[ `echo $output3 | jq '.result'` == "\"Directory was created.\"" ]]
  then
    echo "$APPLIANCE_DIR/$DIR_TO_USE in $APPLIANCE_IP created successfully"
  else
    mkdir -p $ERROR_DIR
    echo "ERROR: createDir FAILED"
    echo "REST response written logged to $ERROR_DIR/createDir_ERROR.json"
    echo $output3 > $ERROR_DIR/createDir_ERROR.json
  fi
}

#Fn that deletes a dir
function deleteDir {
  #Curl command that deletes a given dir; requires certain variables to be set
  output3=$(curl -s -k https://$APPLIANCE_IP:$REST_PORT/mgmt/filestore/default/$APPLIANCE_DIR/$DIR_TO_USE -X DELETE -u $USERNAME:$PASSWORD -H "ibm-mq-rest-csrf-token: value")

  #Error Handling: Ensuring the REST Call was made successfully
  if [[ `echo $output3 | jq '.result'` == "\"Directory was deleted.\"" ]]
  then
    echo "$APPLIANCE_DIR/$DIR_TO_USE in $APPLIANCE_IP deleted successfully"
  else
    mkdir -p $ERROR_DIR
    echo "ERROR: deleteDir FAILED"
    echo "REST response written logged to $ERROR_DIR/deleteDir_ERROR.json"
    echo $output3 > $ERROR_DIR/deleteDir_ERROR.json
  fi

}

#Fn that creates a file in the appliance via REST API
function putFile {
  #Converting the file content to be in base64 format
  fileContentBase64=`print $fileContent1|base64`

  #Curl command that creates a file in the appliance; requires certain variables to be set.
  output3=$(curl -s -k https://$APPLIANCE_IP:$REST_PORT/mgmt/filestore/default/$APPLIANCE_DIR/$DIR_TO_USE -X POST -u $USERNAME:$PASSWORD -H "ibm-mq-rest-csrf-token: value" -H "Content-Type: application/json" --data "{
    \"file\": {
      \"name\":\"$EXEC_FILE_NAME\",
      \"content\":\"$fileContentBase64\"
    }
  }")

  #Error Handling: Ensuring the REST Call was made successfully
  if [[ `echo $output3 | jq '.result'` == "\"File was created.\"" ]]
  then
    echo "$APPLIANCE_DIR/$DIR_TO_USE/$EXEC_FILE_NAME in $APPLIANCE_IP created successfully"
  else
    mkdir -p $ERROR_DIR
    echo "ERROR: putFile FAILED for "$controlName" with "$qmgr
    echo REST response written logged to $ERROR_DIR/$ERROR_FILE_NAME
    echo $output3 > $ERROR_DIR/$ERROR_FILE_NAME
  fi
}

#Fn that executes all the files in $APPLIANCE_DIR/$DIR_TO_USE/$EXEC_FILE_NAME
function execFile {
  output3=$(curl -s -k https://$APPLIANCE_IP:$REST_PORT/mgmt/actionqueue/default -X POST -u $USERNAME:$PASSWORD -H "ibm-mq-rest-csrf-token: value" -H "Content-Type: application/json" --data "{
    \"ExecConfig\" : {
      \"URL\" : \"$APPLIANCE_DIR:/$DIR_TO_USE/$EXEC_FILE_NAME\"
    }
  }")

  #Error Handling: Ensuring the REST Call was made successfully
  if [[ `echo $output3 | jq '.ExecConfig'` == "\"Operation completed.\"" ]]
  then
    echo "$APPLIANCE_DIR/$DIR_TO_USE/$EXEC_FILE_NAME in $APPLIANCE_IP executed successfully"
  else
    mkdir -p $ERROR_DIR
    echo "ERROR: execFile FAILED for" $controlName" with "$qmgr
    echo REST response written logged to $ERROR_DIR/$ERROR_FILE_NAME
    echo $output3 > $ERROR_DIR/$ERROR_FILE_NAME
  fi
}

#Fn that shows any given config file in the appliance
function getConfigFile {
  output3=$(curl -s -k https://$APPLIANCE_IP:$REST_PORT/mgmt/filestore/default/$CONFIG_FILE_PATH/$CONFIG_FILE -X GET -u $USERNAME:$PASSWORD)

  #Error Handling: Ensuring the REST Call was made successfully
  if [[ `echo $output3 | jq '.file'` != "" ]]
  then
    echo "$CONFIG_FILE_PATH/$CONFIG_FILE in $APPLIANCE_IP retrieved successfully"
  else
    mkdir -p $ERROR_DIR
    echo "ERROR: getConfigFile FAILED for "$controlName
    echo REST response written logged to $ERROR_DIR/$ERROR_FILE_NAME
    echo $output3 > $ERROR_DIR/$ERROR_FILE_NAME
  fi

  #Decoding the file content from binary to readable text
  OUTPUT=`echo $output3 | jq '.file' | tr -d \" | base64 --decode`
}
