# IBM MQ Appliance MQ CLI client
The IBM MQ Appliance provides an SSH interface for executing commands from a remote system. However, to maintain the integrity of the appliance, the SSH interface that is provided does not support all the features of an standard SSH server. The current restrictions mean that it is necessary for scripts to simulate an interactive user session with the appliance, which is commonly achieved by using *expect*.

This MQ CLI client can be used to simplify scripts on remote systems by hiding the use of *expect*. A command can be supplied to the client as a parameter, or commands can be supplied using standard input (either interactively or piped in from a file), which makes it easy to script commands as per on other MQ server platforms.

In the interactive mode a custom command is available that can be used to change the expect timeout for subsequent commands that are executed in the session. This command is useful when executing commands that are potentially long-running. To set the timeout use the command *timeout <seconds>*. For example, to set the timeout to 30 seconds use *timeout 30*.

Two implementations of the client are provided; one written in Perl (*mqcli.pl*) and another written in Python (*mqcli.py*). These scripting languages are commonly installed on UNIX and Linux systems.

The Expect module used by the Python client is often provided as a separate package on Linux, named either *python-pexpect* or *pexpect*. Alternatively, the module can be downloaded from the Python Package Index https://pypi.org using the *pip* utility.

The Expect module used by the Perl client is not usually provided with a default Perl installation, but it can be readily downloaded from CPAN (Comprehensive Perl Archive Network), which is the public repository for a wide range of Perl modules. CPAN is available at www.cpan.org. Perl installations include a *cpan* utility that can be used to download Perl modules and prerequisites they require.

## Usage

```
------------------------------
IBM MQ Appliance MQ CLI client
------------------------------

To display usage information:

  mqcli.pl [ -h|help|? ]

To execute MQ CLI commands:

  mqcli.pl -c|command <command> | -i|interactive
           [ -a|appliance <hostname> ]
           [ -u|username <username> ]
           [ -p|password <password> ]
           [ -s|sshoptions <options> ]
           [ -t|timeout <seconds> ]

Parameter information:

  -a : The hostname or IP address of the appliance
  -c : A single MQ control command to execute
  -i : Interactive mode
  -p : The password for the MQ administrator
  -s : Extra SSH command line options, if required
  -t : The timeout to use for expect in seconds
  -u : The username of the MQ administrator on the appliance

Some parameters can alternatively be set as environment variables: 

 - APPLIANCENAME : The hostname or IP address of the appliance
 - APPLIANCEUSER : The username of the MQ administrator on the appliance
 - APPLIANCEPASS : The password for the MQ administrator

If credentials are not specified on the command line, or by using
environment variables, then the user is prompted to enter them
interactively if a terminal is available.

In interactive mode the expect timeout can be modified for subsequent
commands by entering 'timeout <seconds>'. This is useful when executing
a potentially long-running command.
```

## Example 1: Execute a single command

This example illustrates how to use the Perl client to execute a single command by providing the hostname, the credentials and the command using parameters.

```
$ mqcli.pl -a mqappl1 -u admin -p abcd1234 -c dspmqver
Name:        IBM MQ Appliance
Version:     9.1.2.0
Level:       p912-L190308
BuildType:   IKAP - (Production)
Platform:    IBM MQ Appliance
MaxCmdLevel: 912
```

## Example 2: Interactive use

This example illustrates how to enter multiple commands using an interactive session. Output from each MQ control command is returned to the user when the command completes. The user is also prompted to enter their appliance credentials interactively.

```
$ mqcli.pl -a mqappl1 -i
login: admin
password: 
[admin@mqappl1 mqcli]$ dspmq
[admin@mqappl1 mqcli]$ crtmqm QM1 
Please wait while 64 GB file system is initialized for queue manager 'QM1'.
IBM MQ Appliance queue manager created.
The queue manager is associated with installation 'MQAppliance'.
Creating or replacing default objects for queue manager 'QM1'.
Default objects statistics : 83 created. 0 replaced. 0 failed.
Completing setup.
Setup completed.
[admin@mqappl1 mqcli]$ strmqm QM1
IBM MQ Appliance queue manager 'QM1' starting.
The queue manager is associated with installation 'MQAppliance'.
5 log records accessed on queue manager 'QM1' during the log replay phase.
Log replay for queue manager 'QM1' complete.
Transaction manager state recovered for queue manager 'QM1'.
IBM MQ Appliance queue manager 'QM1' started using V9.1.2.0.
[admin@mqappl1 mqcli]$ dspmq
QMNAME(QM1)                                               STATUS(Running)
[admin@mqappl1 mqcli]$ exit 
```

## Example 3: Execute multiple commands non-interactively

This example illustrates how commands can be defined in a file then executed non-interactively using a standard Linux/UNIX pipe. The prompt and commands are included in the output to identify the start of each command. This example also illustrates how the appliance hostname and the credentials can be defined using environment variables.

```
$ cat mqcli.in 
dspmqver
dspmq
status
status QM1

$ export APPLIANCENAME=mqappl1
$ export APPLIANCENAME=admin
$ export APPLIANCEPASS=abcd1234

$ cat mqcli.in | mqcli.pl -i > mqcli.out

$ cat mqcli.out
[admin@mqappl1 mqcli]$ dspmqver
Name:        IBM MQ Appliance
Version:     9.1.2.0
Level:       p912-L190308
BuildType:   IKAP - (Production)
Platform:    IBM MQ Appliance
MaxCmdLevel: 912
[admin@mqappl1 mqcli]$ dspmq
QMNAME(QM1)                                               STATUS(Running)
[admin@mqappl1 mqcli]$ status
Memory:                                  5323MB used, 189.1GB total [3%]
CPU:                                     0%
CPU load:                                0.28, 0.11, 0.17
Internal disk:                           196608MB allocated, 2979.5GB total [6%]
System volume:                           5435MB used, 14.7GB allocated [36%]
MQ errors file system:                   173MB used, 1 FDCs, 15.8GB allocated [1%]
MQ trace file system:                    177MB used, 31.5GB allocated [1%]
[admin@mqappl1 mqcli]$ status QM1
QM(QM1)                                  Status(Running)
CPU:                                     0.00%
Memory:                                  189MB
Queue manager file system:               245MB used, 63.0GB allocated [0%]
[admin@mqappl1 mqcli]$ exit
```
