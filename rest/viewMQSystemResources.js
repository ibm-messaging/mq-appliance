/***************************************************************************
 * Copyright 2016 IBM Corporation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * 
 *     http://www.apache.org/licenses/LICENSE-2.0
 * 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 ***************************************************************************/
 
var https = require('https');

var host     = process.argv[2];
var username = process.argv[3];
var password = process.argv[4];

var port     = 5554;
var path     = '/mgmt/status/default/MQSystemResources';

var options  = {
  host: host,
  port: port,
  path: path,
  auth: username + ':' + password,
  method: 'GET',
  rejectUnauthorized: false,
  requestCert: true,
  agent: false
}

var req = https.request(options, (res) => {
  var responseString = '';

  res.on('data', function(data) {
    responseString += data;
  });

  res.on('end', function() {
    var responseObject = JSON.parse(responseString);
    
    if (responseObject.error !== undefined) {
      console.log('Error: ' + responseObject.error[0]);
      process.exit(1);
    }
    else if (responseObject.MQSystemResources !== undefined) {
      console.log('MQ System Resource Availability on ' + host + ':');
      console.log('Used Storage/Total Available: ' +
                  responseObject.MQSystemResources.UsedStorage + '/' +
                  responseObject.MQSystemResources.TotalStorage + ' (' +
                  ((responseObject.MQSystemResources.UsedStorage / responseObject.MQSystemResources.TotalStorage) * 100).toFixed(2) + '%)');
      console.log('Used Error Storage/Total Available: ' +
                  responseObject.MQSystemResources.UsedErrorsStorage + '/' +
                  responseObject.MQSystemResources.TotalErrorsStorage + ' (' +
                  ((responseObject.MQSystemResources.UsedErrorsStorage / responseObject.MQSystemResources.TotalErrorsStorage) * 100).toFixed(2) + '%)');
      console.log('Used Trace Storage/Total Available: ' +
                  responseObject.MQSystemResources.UsedTraceStorage + '/' +
                  responseObject.MQSystemResources.TotalTraceStorage + ' (' +
                  ((responseObject.MQSystemResources.UsedTraceStorage / responseObject.MQSystemResources.TotalTraceStorage) * 100).toFixed(2) + '%)');
    }
    else {
      console.log('Couldn\'t retrieve system memory status from ' + host + '.');
      process.exit(1);
    }
  });
});
req.end();

req.on('error', (e) => {
  console.log('Error: A connection could not be established to ' + host + '.');
  process.exit(1);
});

