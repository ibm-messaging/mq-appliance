/***************************************************************************
 * This Node.js sample demonstrates how to download a queue manager error
 * log using the system management REST API on the MQ Appliance.
 * 
 * Copyright 2017 IBM Corporation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * 
 * http://www.apache.org/licenses/LICENSE-2.0
 * 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 ***************************************************************************/

if ( ( process.argv.length != 7 )
  && ( process.argv.length != 8 ) ) {
  console.log('Usage: node getQueueManagerErrorLog.js ' +
              '<host> <port> <user> <password> <qmname> [ <logfile> ]');

  process.exitCode = 1;
}
else
{
  // --------------
  // Initialization
  // --------------

  var fs       = require('fs');
  var https    = require('https');

  var host     = process.argv[2];    // The hostname of the appliance
  var port     = process.argv[3];    // The REST management interface port
  var user     = process.argv[4];    // The appliance user to connect as
  var password = process.argv[5];    // The appliance user's password
  var qmname   = process.argv[6];    // The name of the queue manager
  
  var logfile  = 'AMQERR01.LOG';     // The error log file to download
  
  if ( process.argv.length > 7 )
  {
    logfile = process.argv[7];
  }
  
  // ------------------------------------------------------------
  // Build a REST request to download the queue manager error log
  // ------------------------------------------------------------
    
  var path = '/mgmt/filestore/default/mqerr/qmgrs/' + qmname + '/' + logfile;
  
  var options = {
    host: host,
    port: port,
    path: path,
    auth: user + ':' + password,
    method: 'GET',
    rejectUnauthorized: false,
    requestCert: true,
    agent: false
  }
    
  console.log('Downloading ' + logfile + ' for queue manager ' + 
              qmname + ' on appliance ' + host + '...');
  
  var request = https.request(options, (response) => {
    var responseString = '';
  
    // ----------------------------------------------
    // Event handler to receive the streamed response
    // ----------------------------------------------

    response.on('data', (data) => {
      responseString += data;
    });
  
    // -------------------------------------
    // Event handler to process the response
    // -------------------------------------

    response.on('end', () => {
  
      // Parse the JSON content
      var responseObject = JSON.parse(responseString);
  
      // If we have an error attribute then something went wrong,
      // for example, we failed to authenticate or the queue manager
      // error log does not exist
      if ( responseObject.error !== undefined ) {
        console.log('ERROR: ' + responseObject.error[0]);

        process.exitCode = 1;
        return;
      }
  
      // If we don't have the file content then the response is malformed
      if ( responseObject.file === undefined ) {
        console.log('ERROR: File content not found in response');

        process.exitCode = 1;
        return;
      }
  
      // The file content is base64 encoded so it can be returned
      // as part of the JSON response - we need to decode it next
      console.log('Response received - decoding base64 file content...');
  
      var fileBuffer = Buffer.from(responseObject.file, 'base64');
  
      // Now we've decoded the content save the log file to disk
      console.log('Saving the error log file to the current working directory...');
  
      var fileOptions = {
        encoding: null,
        mode: 0o666,
        flag: 'w'
      };
  
      fs.writeFileSync(logfile, fileBuffer, fileOptions);
      
      console.log('File downloaded successfully!');  
    });
  });
  
  // ---------------------
  // Send the REST request
  // ---------------------

  request.end();
  
  // -------------------------------------------------
  // Event handler for when the request cannot be sent
  // -------------------------------------------------

  request.on('error', (error) => {
    console.log('ERROR: A connection could not be established to ' + host);
  
    process.exitCode = 1;
    return;
  });
}
