One of the Target Types for a Log Target on the IBM MQ Appliance is SNMP and this type of Log Target generates a special SNMP trap when an event occurs that is relevant to the Log Target. The trap contains details of the particular log message that generated the trap.

One of the new features in the 9.1.3 firmware is that status notifications are issued when HA and DR queue managers, and the HA group, change state.

These notifications can be sent to an Appliance Log Target so taken together it is now possible to get an SNMP trap generated when there is a change of state of HA or DR. For example you can generate an SNMP trap if the HA status of a queue manager changes to "Remote appliance unavailable" and an example showing how to configure that is given here, for both SNMP v2c and v3.

Multiple SNMP Log Targets can be defined to allow for more control over which log targets are currently active.

# Event Codes

A Log Target can include or exclude individual events based on codes such as 0x8d003594, which is the code for the message corresponding to the HA status of "Remote appliance unavailable".

If you want to generate SNMP traps only for specific events then you will need to know the corresponding event codes.

Each queue manager HA status message has a unique code so a Log Target can be created for one specific message, or you can create one Log Target for all of them, or any combination of messages.

The easiest way to see all of the messages, including their codes, is to create a Log Target with an Event Category of qmgr and a Minimum Event Priority of debug which will match every qmgr message. I created a Log Target with a Log Format of Text and a File Name of logstore:///qmgr-log

If you then run through the scenarios you are interested in you should have the full set of messages.

The scenario I am going to use in the examples here is disconnecting the HA replication interface, in my case the default eth21, and then reconnecting it five minutes later.

I will show the messages relating to an individual HA queue manger named HAQM1.

I then ran through the scenario and at the end I looked at the file logstore:///qmgr-log on the Appliance where the queue manager HAQM1 was running and saw:
<pre>
20191101T103651.811Z [0x8d003576][qmgr][error] : AMQ3576E: HA replication to remote appliance 'banba' for queue manager 'HAQM1' using interface 'eth21' is unavailable
20191101T103652.268Z [0x8d003594][qmgr][error] : AMQ3594E: HA status for queue manager HAQM1 is 'Remote appliance unavailable'
20191101T104106.599Z [0x8d003577][qmgr][info] : AMQ3577I: HA replication to remote appliance 'banba' for queue manager 'HAQM1' using interface 'eth21' is available
20191101T104107.179Z [0x8d003598][qmgr][warn] : AMQ3598W: HA status for queue manager HAQM1 is 'Synchronization in progress'
20191101T104107.516Z [0x8d003599][qmgr][info] : AMQ3599I: HA status for queue manager HAQM1 is 'Normal'
</pre>

These messages give you the three pieces of information necessary to configure a log target to match them:
1. the event code, for example 0x8d003594
2. the event category, in this case qmgr
3. the event priority such as error, info or warn

# SNMP Version 2c

I will begin by using SNMP version 2c as that is easier to configure.

A later section will describe the additions and changes necessary to use SNMP version 3.

The c relates to the use of communities for security. In this example I will use a community of john for the traps from the MQ Appliances.

## snmptrapd

I used the standard Linux tool snmptrapd to receive the traps from my Appliances.

I copied the file mqNotificationMIB.txt from one of my Appliances to the directory /usr/share/snmp/mibs, which is the default location for MIBs, before running snmptrapd.

I created a file snmptrapd.conf in the home directory of the root user on my Linux system, containing the single line:
<pre>
authCommunity log john
</pre>

This tells snmptrapd to accept traps for the community john and to log them.

I ran snmptrapd in the foreground using the command:
<pre>
snmptrapd -c /root/snmptrapd.conf -C -f -Le -m ALL
</pre>

This command tells snmptrapd to use just the configuration file I specified (-c and -C), to run in the foreground (-f), to log to stderr (-Le) and to use all MIBs in the default location of /usr/share/snmp/mibs (-m ALL).

## Appliance SNMP Configuration

To be able to send the notification trap it is necessary to configure at least one Trap and Notification Target in the SNMP Settings. I did it in the console.

I configured the target as follows:
* Remote Host Address: 192.168.122.64
* Remote Port: 162
* Community: john
* Version: 2c

The Remote Host Address is an IP address on the host where I run snmptrapd.

The Remote Port is the default port for SNMP traps.

The Community matches the community I configured in snmptrapd.

The Version matches the configuration of snmptrapd.

## SNMP Log Targets

I created two Log Targets:
1. a Log Target for just the "Remote appliance unavailable" message
2. a Log Target for just the "Normal" message

I created separate Log Targets so I could manage whether I got notifications for one or both messages by enabling or disabling each Log Target independently.

I could have created a single Log Target for queue manager HA status messages so that I could enable or disable all notifications with a single action.

The Log Target for the "Remote appliance unavailable" message was configured as follows:
* Target Type: SNMP
* Event Filter:
  * Event Subscription Filter for code 0x8d003594
* Event Subscriptions:
  * Event Category: qmgr
  * Minimum Event Priority: error

The Log Target for the "Normal" message was configured as follows:
* Target Type: SNMP
* Event Filter:
  * Event Subscription Filter for code 0x8d003599
* Event Subscriptions:
  * Event Category: qmgr
  * Minimum Event Priority: information

## Testing the SNMP Log Targets

The MQ Appliance allows you to generate log events to test your Log Targets without having to generate the conditions for the real log messages to be produced.

If you go to the Administration part of the console and expand the Debug section you should see a Troubleshooting item. If you click on that you will get a page with various debug/troubleshooting tools, one of which is "Generate Log Event" which allows you to enter a Log Category etc. and then generate a log event for any log message.

To test that a trap is generated for a "Remote appliance unavailable" message I filled in the fields as follows:
* Log Category: qmgr
* Log Level: error
* Log Message: debug log event
* Event Code: 0x8d003594

I then clicked Generate Log Event and clicked Confirm on the pop-up that appeared.

I saw the resulting trap in the output from snmptrapd (I have split it into multiple lines to make it easier to read and added the closing round bracket after 282 as that appeared to have been omitted):
<pre>
DISMAN-EVENT-MIB::sysUpTimeInstance = Timeticks: (665587978) 77 days, 0:51:19.78

SNMPv2-MIB::snmpTrapOID.0 = OID: IBM-MQ-APPLIANCE-NOTIFICATION-MIB::mqLogInternalNotification	

IBM-MQ-APPLIANCE-NOTIFICATION-MIB::mqNotificationType.0 = INTEGER: <b>qmgr</b>(282)

IBM-MQ-APPLIANCE-NOTIFICATION-MIB::mqNotificationSeverity.0 = INTEGER: <b>error</b>(4)	

IBM-MQ-APPLIANCE-NOTIFICATION-MIB::mqNotificationTime.0 = STRING: Wed Oct 30 2019 15:24:41	

IBM-MQ-APPLIANCE-NOTIFICATION-MIB::mqNotificationTransId.0 = Gauge32: 0	

IBM-MQ-APPLIANCE-NOTIFICATION-MIB::mqNotificationText.0 = STRING: <b>debug log event</b>	

IBM-MQ-APPLIANCE-NOTIFICATION-MIB::mqNotificationDomain.0 = STRING: default	

IBM-MQ-APPLIANCE-NOTIFICATION-MIB::mqNotificationEventCode.0 = STRING: <b>0x8d003594</b>	

SNMPv2-MIB::snmpTrapEnterprise.0 = OID: IBM-MQ-APPLIANCE-NOTIFICATION-MIB::mqNotificationDefinitions
</pre>

The information I entered in the MQ Appliance console is shown in bold. If you have configured more than one log message to generate a trap then you will have to look at the information in bold to determine which log message triggered the trap and for which queue manager the message was logged, which is part of the mqNotificationText for a real message.

# Running the scenario

With snmptrapd running I went through the scenario and saw the following traps relating to HAQM1 logged by snmp, again I have formatted them to make them easier to read.

The first trap was:
<pre>
DISMAN-EVENT-MIB::sysUpTimeInstance = Timeticks: (681304674) 78 days, 20:30:46.74	

SNMPv2-MIB::snmpTrapOID.0 = OID: IBM-MQ-APPLIANCE-NOTIFICATION-MIB::mqLogInternalNotification	

IBM-MQ-APPLIANCE-NOTIFICATION-MIB::mqNotificationType.0 = INTEGER: <b>qmgr</b>(282)

IBM-MQ-APPLIANCE-NOTIFICATION-MIB::mqNotificationSeverity.0 = INTEGER: <b>error</b>(4)	

IBM-MQ-APPLIANCE-NOTIFICATION-MIB::mqNotificationTime.0 = STRING: Fri Nov 01 2019 11:04:07	

IBM-MQ-APPLIANCE-NOTIFICATION-MIB::mqNotificationTransId.0 = Gauge32: 0	

IBM-MQ-APPLIANCE-NOTIFICATION-MIB::mqNotificationText.0 = STRING: <b>AMQ3594E: HA status for queue manager HAQM1 is 'Remote appliance unavailable'</b>

IBM-MQ-APPLIANCE-NOTIFICATION-MIB::mqNotificationDomain.0 = STRING: default	

IBM-MQ-APPLIANCE-NOTIFICATION-MIB::mqNotificationEventCode.0 = STRING: <b>0x8d003594</b>	

SNMPv2-MIB::snmpTrapEnterprise.0 = OID: IBM-MQ-APPLIANCE-NOTIFICATION-MIB::mqNotificationDefinitions
</pre>

The second trap was:
<pre>
DISMAN-EVENT-MIB::sysUpTimeInstance = Timeticks: (681346475) 78 days, 20:37:44.75	

SNMPv2-MIB::snmpTrapOID.0 = OID: IBM-MQ-APPLIANCE-NOTIFICATION-MIB::mqLogInternalNotification	

IBM-MQ-APPLIANCE-NOTIFICATION-MIB::mqNotificationType.0 = INTEGER: <b>qmgr</b>(282)

BM-MQ-APPLIANCE-NOTIFICATION-MIB::mqNotificationSeverity.0 = INTEGER: <b>info</b>(7)	

IBM-MQ-APPLIANCE-NOTIFICATION-MIB::mqNotificationTime.0 = STRING: Fri Nov 01 2019 11:11:05	

IBM-MQ-APPLIANCE-NOTIFICATION-MIB::mqNotificationTransId.0 = Gauge32: 0	

IBM-MQ-APPLIANCE-NOTIFICATION-MIB::mqNotificationText.0 = STRING: <b>AMQ3599I: HA status for queue manager HAQM1 is 'Normal'</b>

IBM-MQ-APPLIANCE-NOTIFICATION-MIB::mqNotificationDomain.0 = STRING: default	

IBM-MQ-APPLIANCE-NOTIFICATION-MIB::mqNotificationEventCode.0 = STRING: <b>0x8d003599</b>	

SNMPv2-MIB::snmpTrapEnterprise.0 = OID: IBM-MQ-APPLIANCE-NOTIFICATION-MIB::mqNotificationDefinitions

</pre>

# SNMP v3

Work in progress.