#!/usr/bin/perl -w
use strict;
use warnings;

use lib '.';
use POSIX;
use File::Pid;

use SignalBotDBus;


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
 
# dissociate this process from the controlling terminal that started it and stop being part
# of whatever process group this process was a part of.
POSIX::setsid() or die "Can't start a new session.";
 
# callback signal handler for signals.
$SIG{INT} = $SIG{TERM} = $SIG{HUP} = \&signalHandler;
$SIG{PIPE} = 'ignore';
 
# create pid file in /var/run/
my $pidfile = File::Pid->new( { file => $pidFile, } );
 
$pidfile->write or die "Can't write PID file, /dev/null: $!";
 my $SignalBot = SignalBotDBus->new();
$SignalBot->DBusReactorStart();



# catch signals and end the program if one is caught.
sub signalHandler {
	$SignalBot->DBusReactorStop();    # this will cause the "infinite loop" to exit
}
 

 # do this stuff when exit() is called.
END {
	$pidfile->remove if defined $pidfile;
}
