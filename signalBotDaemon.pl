#!/usr/bin/perl -w
use strict;
use warnings;

use POSIX;
use File::Pid;

require'./signalBot.pl';

# make "signalBot.log" file in /var/log/

my $daemonName    = "signalBot";

my $pidFilePath   = ".";                           # PID file path
my $pidFile       = $pidFilePath . $daemonName . ".pid";


# daemonize
use POSIX qw(setsid);
# chdir '/';
umask 0;
open STDIN,  '/dev/null'   or die "Can't read /dev/null: $!";
open STDOUT, '>>/dev/null' or die "Can't write to /dev/null: $!";
# open STDERR, '>>/dev/null' or die "Can't write to /dev/null: $!"; # Temporary disabled to debug
defined( my $pid = fork ) or die "Can't fork: $!";
exit if $pid;
warn "ich bin der fork";
 
# dissociate this process from the controlling terminal that started it and stop being part
# of whatever process group this process was a part of.
POSIX::setsid() or die "Can't start a new session.";
 
# callback signal handler for signals.
$SIG{INT} = $SIG{TERM} = $SIG{HUP} = \&signalHandler;
$SIG{PIPE} = 'ignore';
 
# create pid file in /var/run/
my $pidfile = File::Pid->new( { file => $pidFile, } );
 
$pidfile->write or die "Can't write PID file, /dev/null: $!";
 

run_signalBot();

 
# catch signals and end the program if one is caught.
sub signalHandler {
	# Funktion wird in main gesucht und nicht in signalBot.pl
	# Liegtwohl daran dass es ein Handler ist und etwas andere regeln gelten.
	# @Todo zum funktionieren bringen. Im moment geht es auch ohne...
	# set_dieNow(1);    # this will cause the "infinite loop" to exit
}
 
# do this stuff when exit() is called.
END {
	$pidfile->remove if defined $pidfile;
}

