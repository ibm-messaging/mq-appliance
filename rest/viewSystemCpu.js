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
var path     = '/mgmt/status/default/SystemCpuStatus';

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

console.log('System CPU Usage on ' + host + ':');

setInterval(function() {
  var req = https.request(options, function(res) {
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
      else if (responseObject.SystemCpuStatus !== undefined) {
        console.log('CPU Usage: ' + responseObject.SystemCpuStatus.CpuUsage);
        
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
}, 2000);

process.stdin.on('readable', () => {
  var chunk = process.stdin.read();
  if (chunk !== null) {
    process.exit();
  }
  else {
    console.log('Press enter to exit.');
  }
});
