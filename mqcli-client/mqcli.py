#!/usr/bin/env python

################################################################################
# Copyright 2019 IBM Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
# http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# This Python script provides a remote command line interface for MQ control
# commands on the IBM MQ Appliance. It establishes an SSH session, then uses
# expect to execute the requested commands and return their output. A single
# command can be executed, or an interactive mode can be used to enter multiple
# commands within the same session. In interactive mode commands are read from
# standard input, so they can also be supplied using piped input.
#
# This script is compatible with Python 2 and Python 3.
################################################################################

import argparse
import os
import pexpect
import re
import sys
import textwrap
import time

from getpass import getpass

################################################################################
# Display a command prompt
################################################################################

def display_prompt():
    '''Display a command prompt'''

    # Strip the domain from the appliance hostname (if any)
    hostname = args.appliance

    match = re.search('[^0-9.]', hostname)

    if match:
        # Not an IP address, strip the domain
        tokens   = hostname.split('.')
        hostname = tokens[0]

    # Display the command prompt
    sys.stdout.write('[' + args.username + '@' + hostname + ' mqcli]$ ')
    sys.stdout.flush()

################################################################################
# Display an error message
################################################################################

def error(message='Unexpected error'):
    '''Output an error message to standard error'''

    sys.stderr.write('ERROR: ' + message + '\n')

################################################################################
# Display a fatal error and exit
################################################################################

def fatal(message='Unexpected error'):
    '''Output a fatal error message to standard error and exit'''

    error(message + '\n')

    if child != None:
        child.close()

    sys.exit(1)

################################################################################
# Parse the command line arguments
################################################################################

def get_arguments():
    '''Parse the command line arguments'''

    # ----------------------------
    # Construct an argument parser
    # ----------------------------

    parser = argparse.ArgumentParser(
        description='IBM MQ Appliance MQ CLI client',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=textwrap.dedent("""\
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
            """)
    )

    # --------------------------------------------------------------------
    # Add the supported modes and require one and only one to be specified
    # --------------------------------------------------------------------

    modes = parser.add_mutually_exclusive_group(required=True)

    modes.add_argument('-c', '--command',
        dest='command',
        metavar='command',
        help='A single MQ control command to execute')

    modes.add_argument('-i', '--interactive',
        dest='interactive',
        action='store_true',
        help='Interactive mode')

    # ---------------------
    # Add the other options
    # ---------------------

    parser.add_argument('-a', '--appliance',
        dest='appliance',
        metavar='appliance',
        help='The hostname or IP address of the appliance')

    parser.add_argument('-u', '--username',
        dest='username',
        metavar='username',
        help='The username of the MQ administrator on the appliance')

    parser.add_argument('-p', '--password',
        dest='password',
        metavar='password',
        help='The password for the MQ administrator')

    parser.add_argument('-s', '--sshoptions',
        dest='sshoptions',
        metavar='options',
        help='Extra SSH command line options, if required')

    parser.add_argument('-t', '--timeout',
        dest='timeout',
        metavar='seconds',
        help='The timeout to use for expect in seconds',
        type=int,
        default=60)

    # ------------------------------------------------------
    # Parse the arguments and return the generated namespace
    # ------------------------------------------------------

    return parser.parse_args()

################################################################################
# Prompt for the appliance user's password
################################################################################

def prompt_password():
    """Prompt for appliance user's password"""

    while args.password == None:
        try:
            password = getpass('password: ')
        except EOFError:
            print()
            return

        # Strip leading/trailing whitespace
        password = password.strip()

        if len(password) > 0:
            args.password = password


################################################################################
# Prompt for the appliance username
################################################################################

def prompt_username():
    '''Prompt for the appliance username'''

    # We're prompting for the user name so ensure we also prompt for the password
    args.password = None  

    while args.username == None:
        sys.stdout.write('login: ')
        sys.stdout.flush()

        username = sys.stdin.readline()
        
        # Give up if we get EOF
        if username == '':
            print()
            return

        # Strip leading/trailing whitespace
        username = username.strip()

        if len(username) > 0:
            args.username = username

################################################################################
# Execute an MQ control command
################################################################################

def run_command(command=''):
    '''Execute an MQ control command'''

    # Send the command
    child.sendline(command)

    # Wait for command prompt, which means the command has completed
    try:
        child.expect_exact('mqa(mqcli)# ', timeout=args.timeout)
    except (pexpect.EOF, pexpect.TIMEOUT):
        fatal('Failed to execute an MQ command')

    # Echo the output, except the first line, which is the command
    lines = child.before.splitlines()

    for line in range(len(lines)):
        if line > 0:
            print(lines[line])

################################################################################
# Execute MQ control commands read from standard input
################################################################################

def run_interactive():
    '''Execute MQ control commands read from standard input'''

    saved_timeout = args.timeout
    end           = False

    while not end:
        # Display a command prompt
        display_prompt()

        # Get the next command from the user   
        command = sys.stdin.readline()

        # Map EOF to 'exit'
        if command == '':
            command = 'exit'

        # Strip leading/trailing whitespace
        command = command.strip()

        # Echo the command if we don't have a terminal to
        # enable the start of each command to be identified
        if not sys.stdin.isatty():
            print(command)

        # Execute the command unless we've been asked to exit
        if re.match('^(exit|top)$', command):
            end = True
        else:
            match = re.match(r'^timeout\b(.*)$', command)

            if match:
                # Special command to update the expect timeout
                set_timeout(match.group(1))
            elif len(command) > 0:
                run_command(command)

    # Restore the saved timeout
    args.timeout = saved_timeout

################################################################################
# Update the expect timeout for an interactive session
################################################################################

def set_timeout(timeout=''):
    '''Update the expect timeout for an interactive session'''

    # Strip leading and trailing whitespace
    timeout = timeout.strip()
    
    # Verify the timeout is an integer greater than zero
    if re.match(r'^\d+$', timeout):
        seconds = int(timeout)
    else:
        seconds = 0

    if seconds > 0:
        args.timeout = seconds
        print('Expect timeout set to ' + timeout + ' second(s)')
    else:
        print('Usage: timeout <seconds>')

################################################################################
# Main Program
################################################################################

child = None
args  = get_arguments()

# ----------------------------------------------
# Ensure the expect timeout is greater than zero
# ----------------------------------------------

if args.timeout <= 0:
    fatal('The timeout must be greater than 0 seconds')

# --------------------------------------------
# Allow the appliance hostname and credentials
# to be defined using environment variables
# --------------------------------------------

if ((args.appliance == None) or (args.appliance == '')) and (os.getenv('APPLIANCENAME') != None):
    args.appliance = os.getenv('APPLIANCENAME')

if ((args.username == None) or (args.username == '')) and (os.getenv('APPLIANCEUSER') != None):
    args.username = os.getenv('APPLIANCEUSER')

if ((args.password == None) or (args.password == '')) and (os.getenv('APPLIANCEPASS') != None):
    args.password = os.getenv('APPLIANCEPASS')

# ----------------------------------------------------
# Ensure we have an appliance hostname and credentials
# ----------------------------------------------------

if ((args.appliance == None) or (args.appliance == '')):
    fatal('The appliance hostname must be specified')

if ((args.username == None) or (args.username == '')):
    if sys.stdin.isatty():
        # We don't have a user name, but we have a terminal
        prompt_username()

    if ((args.username == None) or (args.username == '')):
        fatal('The appliance username must be specified')

if ((args.password == None) or (args.password == '')):
    if sys.stdin.isatty():
        # We don't have a password, but we have a terminal
        prompt_password()

    if ((args.password == None) or (args.password == '')):
        fatal('The appliance user\'s password must be specified')

# --------------------------------------------
# Establish an SSH session to the MQ Appliance
# --------------------------------------------

ssh_command = 'ssh'

if args.sshoptions != None:
    ssh_command = ssh_command + ' ' + args.sshoptions
    
ssh_command = ssh_command + ' ' + args.appliance

if sys.version_info[0] >= 3:
    child = pexpect.spawn(ssh_command, encoding='utf-8')
else:
    child = pexpect.spawn(ssh_command)

if not child.isalive():
    fatal('Failed to spawn ssh')

# ----------------------
# Login to the appliance
# ----------------------

# Wait for the login prompt
try:
    child.expect_exact('login: ', timeout=args.timeout)
except (pexpect.EOF, pexpect.TIMEOUT):
    fatal('Failed to connect to the appliance')

# Send the user name
child.sendline(args.username)

# Wait for the password prompt
try:
    child.expect_exact('Password: ', timeout=args.timeout)
except (pexpect.EOF, pexpect.TIMEOUT):
    fatal('Failed to receive the password prompt')

# Send the password
child.sendline(args.password)

# Wait for the command prompt
try:
    child.expect_exact('mqa# ', timeout=args.timeout)
except (pexpect.EOF, pexpect.TIMEOUT):
    fatal('Failed to login')

# ----------------
# Enter the MQ CLI
# ----------------

child.sendline('mqcli')

try:
    child.expect_exact('mqa(mqcli)# ', timeout=args.timeout)
except (pexpect.EOF, pexpect.TIMEOUT):
    fatal('Failed to enter the MQ CLI')

# -------------------------
# Execute the MQ command(s)
# -------------------------

if args.command != None:
    run_command(args.command)
else:
    run_interactive()

# ---------------
# Exit the MQ CLI
# ---------------

child.sendline('exit')

try:
    child.expect_exact('mqa# ', timeout=args.timeout)
except (pexpect.EOF, pexpect.TIMEOUT):
    fatal('Failed to exit the MQ CLI')

# ------
# Logout
# ------

child.sendline('exit')

# Allow the session to be closed by the appliance
time.sleep(1)

# ----------
# Disconnect
# ----------

child.close()
sys.exit(0)

################################################################################
# End of file
################################################################################
