#!/usr/bin/perl -w

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
# This Perl script provides a remote command line interface for MQ control
# commands on the IBM MQ Appliance. It establishes an SSH session, then uses
# expect to execute the requested commands and return their output. A single
# command can be executed, or an interactive mode can be used to enter multiple
# commands within the same session. In interactive mode commands are read from
# standard input, so they can also be supplied using piped input. 
#
# The Expect Perl module can be installed from CPAN.
################################################################################

# Pragmas
use strict;

# Expect for interactive SSH
use Expect;

# Command line parsing
use Getopt::Long;

# POSIX support for terminal handling
use POSIX;

################################################################################
# Constants
################################################################################

# Constants for boolean states
use constant YES => 1;
use constant NO  => 0;

# Constant for sending an enter/return key
use constant ENTER_KEY => "\n";

################################################################################
# Global variables
################################################################################

# Command line options
my %options;

# The concatenated command line options
my $command_line_options = join(' ', @ARGV);

# The expect session
my $expect;

# Whether an SSH process has been spawned
my $spawned = NO;

################################################################################
# Initialization
################################################################################

# Defaults for our command line options
$options{'appliance'}   = '';
$options{'command'}     = '';
$options{'help'}        = NO;
$options{'interactive'} = NO;
$options{'password'}    = '';
$options{'sshoptions'}  = '';
$options{'timeout'}     = 60;
$options{'username'}    = '';

# Flush output written to STDOUT and STDERR
autoflush STDOUT 1;
autoflush STDERR 1;

################################################################################
# Main program
################################################################################

Getopt::Long::Configure qw(no_auto_abbrev no_ignore_case pass_through);

GetOptions
(
  'help|h|?'       => \$options{'help'},
  'appliance|a=s'  => \$options{'appliance'},
  'command|c=s'    => \$options{'command'},
  'interactive|i'  => \$options{'interactive'},
  'password|p=s'   => \$options{'password'},
  'sshoptions|s=s' => \$options{'sshoptions'},
  'timeout|t=i'    => \$options{'timeout'},
  'username|u=s'   => \$options{'username'},
);

# ------------------------------
# Check for unrecognized options
# ------------------------------

if ( join(' ', @ARGV) )
{
  error ('Unknown options: ' . join(' ', @ARGV));
  display_usage();
  exit 1;
}

# ----------------------------------------
# Check if usage information was requested
# ----------------------------------------

if ( ( $command_line_options =~ m/^\s*$/ )
  || ( $options{'help'} ) )
{
  display_usage();
  exit 0;
}

# ----------------------------------------------
# Ensure the expect timeout is greater than zero
# ----------------------------------------------

if ( $options{'timeout'} <= 0 )
{
  fatal ('The timeout must be greater than 0 seconds');
}

# ----------------------------------------------------------
# Ensure we have a command or interactive mode was requested
# ----------------------------------------------------------

if ( !$options{'command'} && !$options{'interactive'} )
{
  fatal('A command must be provided, or interactive mode requested');
}

# ----------------------------------------
# Ensure we don't have both options either
# ----------------------------------------

if ( $options{'command'} && $options{'interactive'} )
{
  fatal('A command and interactive mode are mutually exclusive');
}

# --------------------------------------------
# Allow the appliance hostname and credentials
# to be defined using environment variables
# --------------------------------------------

if ( ( ! $options{'appliance'} )
  && ( $ENV{'APPLIANCENAME'} ) )
{
  $options{'appliance'} = $ENV{'APPLIANCENAME'};
}

if ( ( ! $options{'username'} )
  && ( $ENV{'APPLIANCEUSER'} ) )
{
  $options{'username'} = $ENV{'APPLIANCEUSER'};
}

if ( ( ! $options{'password'} )
  && ( $ENV{'APPLIANCEPASS'} ) )
{
  $options{'password'} = $ENV{'APPLIANCEPASS'};
}

# ----------------------------------------------------
# Ensure we have an appliance hostname and credentials
# ----------------------------------------------------

if ( ! $options{'appliance'} )
{
  fatal ('The appliance hostname must be specified');
}

if ( ! $options{'username'} )
{
  if ( -t STDIN )
  {
    # We don't have a user name, but we have a terminal
    prompt_username();
  }

  if ( ! $options{'username'} )
  {
    fatal ('The appliance username must be specified');
  }
}

if ( ! $options{'password'} )
{
  if ( -t STDIN )
  {
    # We don't have a password, but we have a terminal
    prompt_password();
  }

  if ( ! $options{'password'} )
  {
    fatal ('The appliance user\'s password must be specified');
  }
}

# --------------------------------------------
# Establish an SSH session to the MQ Appliance
# --------------------------------------------

$expect = Expect -> new();

# Turn off STDOUT echo (we'll manage this ourselves)
$expect -> log_stdout(0);

# Use RAW mode
$expect -> raw_pty(1);

# Spawn a background SSH session
$spawned = $expect -> spawn
(
  join (' ', 'ssh', $options{'sshoptions'}, $options{'appliance'})
);

if ( ! $spawned )
{
  fatal ('Failed to spawn SSH: ' . $!);
}

# ----------------------
# Login to the appliance
# ----------------------

# Wait for the login prompt
my @response = $expect -> expect ($options{'timeout'}, "login: ");

if ( defined $response[1] )
{
  fatal ('Failed to connect or receive the login prompt');
}

# Send the user name
$expect -> send ($options{'username'} . ENTER_KEY);

# Wait for the password prompt
@response = $expect -> expect ($options{'timeout'}, "Password: ");

if ( defined $response[1] )
{
  fatal ('Failed to receive the password prompt');
}

# Send the password
$expect -> send ($options{'password'} . ENTER_KEY);

# Wait for the command prompt
@response = $expect -> expect ($options{'timeout'}, "mqa# ");

if ( defined $response[1] )
{
  fatal ('Failed to login');
}

# ----------------
# Enter the MQ CLI
# ----------------

$expect -> send ('mqcli' . ENTER_KEY);

# Wait for the command prompt
@response = $expect -> expect ($options{'timeout'}, "mqa(mqcli)# ");

if ( defined $response[1] )
{
  fatal ('Failed to enter the MQ CLI');
}

# -------------------------
# Execute the MQ command(s)
# -------------------------

if ( $options{'command'} )
{
  run_command ($options{'command'});
}
else
{
  run_interactive();
}

# ---------------
# Exit the MQ CLI
# ---------------

$expect -> send ('exit' . ENTER_KEY);

@response = $expect -> expect ($options{'timeout'}, "mqa# ");

if ( defined $response[1] )
{
  fatal ('Failed to exit the MQ CLI');
}

# ------
# Logout
# ------

$expect -> send ('exit' . ENTER_KEY);

# Allow the session to be closed by the appliance
sleep 1;

# ----------
# Disconnect
# ----------

disconnect();

exit 0;

################################################################################
# Display usage information
################################################################################

sub display_usage
{
  print <<"--END--";

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

--END--
}

################################################################################
# Disconnect the spawned SSH session
################################################################################

sub disconnect
{
  if ( ( $spawned )
    && ( ! defined ($expect -> exitstatus()) ) )
  {
    $expect -> hard_close();
  }
}

################################################################################
# Display a command prompt
################################################################################

sub display_prompt
{
  # Strip the domain from the appliance hostname (if any)
  my $hostname = $options{'appliance'};

  if ( $hostname =~ m/[^0-9\.]/ )
  {
    $hostname =~ s/\..*$//;
  }

  # Display the command prompt
  print STDOUT '[' . $options{'username'} . '@' . $hostname . ' mqcli]$ ';
}

################################################################################
# Display an error
################################################################################

sub error
{
  my $message = shift || 'Unexpected error';

  print STDERR 'ERROR: ' . $message . "\n";
}

################################################################################
# Display a fatal error and exit
################################################################################

sub fatal
{
  my $message = shift || 'Unexpected error';

  error ($message . "\n");
  disconnect();
  exit 1;
}

################################################################################
# Prompt for the appliance user's password
################################################################################

sub prompt_password
{
  # ----------------------------------------------------
  # Disable terminal echo so the password is not visible
  # ----------------------------------------------------

  my $echo_disabled = NO;

  my $termios = POSIX::Termios -> new();

  $termios -> getattr ( fileno(STDIN) );

  my $lflag = $termios -> getlflag;

  if ( $lflag & &POSIX::ECHO )
  {
    $lflag &= ~&POSIX::ECHO;
    $termios -> setlflag ($lflag);
    $termios -> setattr( fileno(STDIN), &POSIX::TCSANOW );

    $echo_disabled = YES;
  }

  # -----------------------
  # Prompt for the password
  # -----------------------

  while ( ! $options{'password'} )
  {
    print STDOUT 'password: ';

    $options{'password'} = readline (STDIN);

    # Acknowledge input given terminal echo is off
    print STDOUT "\n";

    # Give up if we get EOF
    if ( ! defined ($options{'password'}) )
    {
      return;
    }

    # Strip leading/trailing whitespace
    $options{'password'} =~ s/(^\s+)|(\s+$)//g;
  }

  # ---------------------------------------
  # Restore terminal echo if we disabled it
  # ---------------------------------------

  if ( $echo_disabled )
  {
    $lflag |= &POSIX::ECHO;
    $termios -> setlflag ($lflag);
    $termios -> setattr( fileno(STDIN), &POSIX::TCSANOW );
  }
}

################################################################################
# Prompt for the appliance username
################################################################################

sub prompt_username
{
  # We're prompting for the user name so ensure we also prompt for the password
  $options{'password'} = '';  

  while ( ! $options{'username'} )
  {
    print STDOUT 'login: ';

    $options{'username'} = readline (STDIN);

    # Give up if we get EOF
    if ( ! defined ($options{'username'}) )
    {
      print STDOUT "\n";
      return;
    }

    # Strip leading/trailing whitespace
    $options{'username'} =~ s/(^\s+)|(\s+$)//g;
  }
}

################################################################################
# Execute an MQ control command
################################################################################

sub run_command
{
  my $command = shift || '';

  # Send the command
  $expect -> send ($command . ENTER_KEY);

  # Wait for command prompt, which means the command has completed
  my @response = $expect -> expect ($options{'timeout'}, "mqa(mqcli)# ");

  if ( defined $response[1] )
  {
    fatal('Failed to execute an MQ command');
  }

  if ( defined $response[3] )
  {
    # Obtain the STDOUT from the command
    my @lines = split(/\n/, $response[3]);

    # Discard the first line, which is the command
    shift (@lines);

    # Echo the output
    print STDOUT join ("\n", @lines, '');
  }
}

################################################################################
# Execute one or more MQ control commands read from STDIN
################################################################################

sub run_interactive
{
  my $saved_timeout = $options{'timeout'};
  my $end           = NO;

  while ( ! $end )
  {
    # Display a command prompt
    display_prompt();

    # Get the next command from the user   
    my $command = readline (STDIN);

    # Map EOF to 'exit'
    if ( ! defined ($command) )
    {
      $command = 'exit';
    }

    # Strip leading/trailing whitespace
    $command =~ s/(^\s+)|(\s+$)//g;

    # Echo the command if we don't have a terminal to
    # enable the start of each command to be identified
    if ( ! -t STDIN )
    {
      print STDOUT $command . "\n";
    }

    # Execute the command unless we've been asked to exit
    if ( $command =~ m/^(exit|top)$/ )
    {
      $end = YES;
    }
    elsif ( $command =~ m/^timeout\b(.*)$/ )
    {
      # Special command to update the expect timeout
      set_timeout ($1);
    }
    elsif ( $command )
    {
      run_command ($command);
    }
  }

  # Restore the saved timeout
  $options{'timeout'} = $saved_timeout;
}

################################################################################
# Update the expect timeout for an interactive session
################################################################################

sub set_timeout
{
  my $timeout = shift || '';

  # Strip leading and trailing whitespace
  $timeout =~ s/(^\s+)|(\s+$)//g;

  # Verify the timeout is an integer greater than zero
  if ( ( $timeout =~ m/^\d+$/ ) && ( $timeout > 0 ) )
  {
    $options{'timeout'} = $timeout;
    print STDOUT "Expect timeout set to $timeout seconds\n";
  }
  else
  {
    print STDOUT "Usage: timeout <seconds>\n";
  }
}

################################################################################
# End of file
################################################################################
