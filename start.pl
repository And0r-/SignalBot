#!/usr/bin/perl -w


##################################################################################################################################
##
##	This will start the Signal Bot
##	Use no param to start it with forks in background
##
##	Or You can use a param in development
##	1 => starts the signal client listener with no fork
##
##	You can set "has signal_cli => 'debug';" in config file.
##	so you can input signal messages in signal_input.txt and read outputs in terminal. 
##
##
##	2 => starts the bot background worker to detect starting events and do all the stuff that is not signal message triggered
##
##
##
##
##
##################################################################################################################################


use strict;
use warnings;

use lib '.';
use POSIX;
use File::Pid;

use SignalBot;


my $debug = shift;

if ($debug) {
	# do not fork and output all stuff in terminal
	SignalBot->new->init->signal_cli->StartReactor;
	exit;
}

my $pidFile       = ".signalBot.pid";

# daemonize
use POSIX qw(setsid);
# chdir '/';
umask 0;
open STDIN,  '/dev/null'   or die "Can't read /dev/null: $!";
open STDOUT, '>>/dev/null' or die "Can't write to /dev/null: $!";
# open STDERR, '>>/dev/null' or die "Can't write to /dev/null: $!"; # Temporary disabled to debug
defined( my $pid = fork ) or die "Can't fork: $!";
exit if $pid;
 
# dissociate this process from the controlling terminal that started it and stop being part
# of whatever process group this process was a part of.
POSIX::setsid() or die "Can't start a new session.";
 
# callback signal handler for signals.
$SIG{INT} = $SIG{TERM} = $SIG{HUP} = \&signalHandler;
$SIG{PIPE} = 'ignore';
 
# create pid file in /var/run/
my $pidfile = File::Pid->new( { file => $pidFile, } );
 
$pidfile->write or die "Can't write PID file, /dev/null: $!";
 my $SignalBot = SignalBot->new->init;
$SignalBot->signal_cli->StartReactor;



# catch signals and end the program if one is caught.
sub signalHandler {
	$SignalBot->signal_cli->StopReactor;    # this will cause the "infinite loop" to exit
}
 

 # do this stuff when exit() is called.
END {
	$pidfile->remove if defined $pidfile;
}
