#!/usr/bin/perl -w


##################################################################################################################################
##
##	This will start the Signal Bot
##	Use no param to start it with fork in background
##
##	you have to set the service to start "signalBot" or "timer".
##  for all functions you will need all services.
##
##	the second param you can set for debug mode. So the service will be startet with no fork
##
##	You can set "has signal_cli => 'debug';" in config file.
##	so you can input signal messages in signal_input.txt and read outputs in terminal. 
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

my $service = shift;
my $debug = shift;

my $pidFiles = {
	signalBot => ".signalBot.pid",
	timer => ".signalBotTimer.pid"
};

die "service nicht definiert signalBot oder timer?" unless ($service);

if ($debug && $service eq "signalBot") {
	# do not fork and output all stuff in terminal
	SignalBot->new->init->signal_cli->StartReactor;
	exit;
}

if ($debug && $service eq "timer") {
	# do not fork and output all stuff in terminal
	SignalBot->new->init->timer->start;
	exit;
}

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
 
my $SignalBot;

my $pidfile = File::Pid->new( { file => $pidFiles->{$service}, } );
$pidfile->write or die "Can't write PID file, /dev/null: $!";

if ($service eq "signalBot") {
	# listen everytime for signal messages
	$SignalBot = SignalBot->new->init;
	$SignalBot->signal_cli->StartReactor;
} elsif ($service eq "timer") {
	# do time based stuff. e.g check is starting a event
	$SignalBot = SignalBot->new->init;
	$SignalBot->timer->start;
}


# catch signals and end the program if one is caught.
sub signalHandler {
	if ($service eq "signalBot") {
		$SignalBot->signal_cli->StopReactor; # this will cause the "infinite loop" to exit
	} elsif ($service eq "timer") {
		$SignalBot->timer->stop; # this will cause the "infinite loop" to exit
	}
}
 

 # do this stuff when exit() is called.
END {
	$pidfile->remove if defined $pidfile;
}
