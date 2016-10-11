# Monitoring an IBM(R) MQ Appliance HA Solution

This repository contains samples showing how to monitor:

1. an HA Queue manager
2. an HA Group of two IBM MQ Appliances

Each sample consists of an expect script and a shell script to configure and
run the expect script. The expect scripts connect to a pair of Appliances
using ssh.

The scripts were tested with the 8.0.0.5-IBM-MQ-Appliance-IT16174 interim fix.

## Monitor an HA Queue Manager

The expect script for this is mqa_ha_qm_status.exp

This script is configured with information about two Appliances, that are configured as an HA Group, and one queue manager. The script connects to the appliances and periodically (every five seconds) issues the mqcli status command for the queue manager on each appliance. It outputs one line of output for each queue manager each time it issues the status command.

Each line of output consists of the following comma-separated values:

1. the DNS name or IP address of the appliance interface that the script connected to
2. the unique system identifier of the appliances
3. the (non-HA) status of the queue manager
4. the percentage of CPU used by the queue manager
5. the amount of memory used by the queue manager
6. the percentage of the queue manager file system used
7. the HA role of the queue manager
8. the HA status of the queue manager
9. if the queue manager is under HA control
10. the HA preferred location of the queue manager

The monitorHAQM1 is a sample script showing how to configure the necessary environment variables and invoke the expect script. You should copy this script for each HA queue manager you wish to monitor and update the environment variables accordingly.

Here is some sample output from when I ran the monitorHAQM1 script after configuring it for my pair of appliances in an HA Group:

```
mgt0-mqactla3.hursley.ibm.com,mqactla3,Running,0.56,200,4,Primary,Normal,Enabled,This appliance
mgt0-mqactla4.hursley.ibm.com,mqactla4,Running elsewhere,n/a,n/a,n/a,Secondary,Normal,Enabled,Other appliance
mgt0-mqactla3.hursley.ibm.com,mqactla3,Running,0.54,200,4,Primary,Normal,Enabled,This appliance
mgt0-mqactla4.hursley.ibm.com,mqactla4,Running elsewhere,n/a,n/a,n/a,Secondary,Normal,Enabled,Other appliance
mgt0-mqactla3.hursley.ibm.com,mqactla3,Running,0.52,200,4,Primary,Normal,Enabled,This appliance
mgt0-mqactla4.hursley.ibm.com,mqactla4,Running elsewhere,n/a,n/a,n/a,Secondary,Normal,Enabled,Other appliance
```

At around the same time this output was produced I ran the command `status HAQM1` on each appliance.

The output from the first appliance, mqactla3, was:

```
QM(HAQM1)                                Status(Running)
CPU:                                     0.76%
Memory:                                  200MB
Queue manager file system:               2648MB used, 63.0GB allocated [4%]
HA role:                                 Primary
HA status:                               Normal
HA control:                              Enabled
HA preferred location:                   This appliance
```

The output from the second appliance, mqactla4, was:

```
QM(HAQM1)                                Status(Running elsewhere)
HA role:                                 Secondary
HA status:                               Normal
HA control:                              Enabled
HA preferred location:                   Other appliance
```

## Monitor an Appliance HA Group

The expect script for this is mqa_ha_status.exp

This script is configured with information about two appliances that are configured as an HA Group. The script connects to each of the appliances and periodically (every five seconds) issues the mqcli `status` command, without a queue manager name, to get information about the CPU, disk and memory usage of the appliance as a whole. It then runs the mqcli `dsphagrp` command to get the HA status of the two appliances in the HA Group.

One line of output is produced for each appliance.

Each line of output consists of the following comma-separated values:

1. the DNS name or IP address of the appliance interface that the script connected to
2. the unique system identifier of the appliances
3. the percentage of memory used
4. the percentage of CPU used
5. the percentage of the Internal disk used
6. the percentage of the System volume used
7. the percentage of the MQ errors file system used
8. the percentage of the MQ trace file system used
9. the status of this appliance in the HA Group
10. the status of the other appliance in the HA Group

The monitorGroup1 script is a sample script showing how to configure the necessary environment variables and invoke the expect script. You should copy this script for each HA Group you wish to monitor and update the environment variables accordingly.

Here is some sample output:

```
mgt0-mqactla3.hursley.ibm.com,mqactla3,2,0,23,72,1,84,Online,Online
mgt0-mqactla4.hursley.ibm.com,mqactla4,2,0,17,80,1,90,Online,Online
mgt0-mqactla3.hursley.ibm.com,mqactla3,2,0,23,72,1,84,Online,Online
mgt0-mqactla4.hursley.ibm.com,mqactla4,2,0,17,80,1,90,Online,Online
mgt0-mqactla3.hursley.ibm.com,mqactla3,2,0,23,72,1,84,Online,Online
mgt0-mqactla4.hursley.ibm.com,mqactla4,2,0,17,80,1,90,Online,Online
```

At the same time that I ran the monitorGroup1 script to produce the above output, I ran the commands on each appliance.

The output from mqactla3 was:

```
mqa(mqcli)# status
Memory                                   3716MB used, 189.1GB total [2%]
CPU:                                     0%
CPU load:                                0.00, 0.00, 0.00
Internal disk:                           262148MB allocated, 1115.9GB total [23%]
System volume:                           10852MB used, 14.7GB allocated [72%]
MQ errors file system:                   173MB used, 1 FDCs, 15.8GB allocated [1%]
MQ trace file system:                    27061MB used, 31.5GB allocated [84%]
mqa(mqcli)# dsphagrp
This Appliance: Online
Appliance mqactla4: Online
```

The output from mqactla4 was:

```
mqa(mqcli)# status
Memory                                   3542MB used, 189.1GB total [2%]
CPU:                                     0%
CPU load:                                0.08, 0.01, 0.00
Internal disk:                           196612MB allocated, 1115.9GB total [17%]
System volume:                           12037MB used, 14.7GB allocated [80%]
MQ errors file system:                   173MB used, 0 FDCs, 15.8GB allocated [1%]
MQ trace file system:                    28960MB used, 31.5GB allocated [90%]
mqa(mqcli)# dsphagrp
This Appliance: Online
Appliance mqactla3: Online
```
