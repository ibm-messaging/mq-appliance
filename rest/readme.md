# Monitoring an IBM MQ Appliance using the RESTful API in Node.js
The example scripts found in this repository were written to use Node.js. They can be run from the console using:
```
node filename.js <appliance ip> <username> <password>
```
Make sure the REST interface is enabled on the appliance by logging in to the appliance and running:
```
config; rest-mgmt; admin-state enabled; exit; write mem; exit;
```
If your appliance is not using the default REST port of 5554, you will need to update the example scripts.
## viewQueueManagers.js
This script retrieves the names and statuses of the queue managers currently on the appliance.
## viewSystemCpu.js
This script retrieves the current CPU usage of the appliance every two seconds. Press enter to exit the process when you have finished viewing the output.
## viewSystemMemory.js
This script retrieves the current memory usage of the appliance, as well as the used and total memory available.
## viewMQSystemResources.js
This script retrieves the storage information on the appliance, including amount of used storage, total available, user error storage, and etc.
## getQueueManagerErrorLog.js
This script downloads a queue manager error log from an appliance (e.g. AMQERR01.LOG).
