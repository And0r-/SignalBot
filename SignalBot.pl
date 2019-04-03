#!/usr/bin/perl -w
use strict;
use warnings;

use JSON;
use Data::Dumper;
use Time::Piece;
use POSIX;
use File::Pid;

warn "start";

# make "signalBot.log" file in /var/log/

my $daemonName    = "signalBot";

my $dieNow        = 0;                                     # used for "infinte loop" construct - allows daemon mode to gracefully exit
my $logging       = 1;                                     # 1= logging is on
my $logFilePath   = "log/";                           # log file path
my $logFile       = $logFilePath . $daemonName . ".log";
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
 
# turn on logging
if ($logging) {
	open LOG, ">>$logFile";
	select((select(LOG), $|=1)[0]); # make the log file "hot" - turn off buffering
}


my $json = JSON->new->allow_nonref;


my $statistic = {};
my @events;
my @events_backup;
my @send_messages;

require'./config.pl';

 
# "infinite" loop where some useful process happens
until ($dieNow) {
	
 
	# Todo: persistent() the data on disk

	event_trigger();
	send_messages();
	recive_messages();
 
	# logEntry("log something"); # use this to log whatever you need to
}
 
# add a line to the log file
sub logEntry {
	my ($logText) = @_;
	my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) = localtime(time);
	my $dateTime = sprintf "%4d-%02d-%02d %02d:%02d:%02d", $year + 1900, $mon + 1, $mday, $hour, $min, $sec;
	if ($logging) {
		print LOG "$dateTime $logText\n";
	}
}
 
# catch signals and end the program if one is caught.
sub signalHandler {
	$dieNow = 1;    # this will cause the "infinite loop" to exit
}
 
# do this stuff when exit() is called.
END {
	if ($logging) { close LOG }
	$pidfile->remove if defined $pidfile;
}


sub event_trigger {

	my $t = localtime;
	my $t_2h_reminder = localtime(time + 2*60*60);

	foreach my $event_index (0 .. $#events) {
		if ($t->epoch >= $events[$event_index]->{"time"}) {
			push(@send_messages, {message => "Event Startet Jetzt", response_to => $events[$event_index]->{"message"}});

			push(@events_backup, $events[$event_index]);
			delete $events[$event_index];
		} elsif ($t_2h_reminder->epoch >= $events[$event_index]->{"time"} && !$events[$event_index]->{"2h_reminder_done"}){
			$events[$event_index]->{"2h_reminder_done"} = 1;
			push(@send_messages, {message => "REMINDER: Event startet in 2 Stunden", response_to => $events[$event_index]->{"message"}});
		}
	}
} 

sub recive_messages {
	logEntry("recive message");
	my $cmd = get_signal_cli_path().' -u '.get_bot_number().' receive --json';
	my $messages = `$cmd`;
	logEntry($messages);
	return unless ($messages);
	# Multiple messages are spitet by new line
	foreach my $message (split(/\n/, $messages)) {
			$message = $json->decode( $message );

			# There is a lot of background messages. when a user recive a message to say i get this on this device... Ignore it at the moment
			next unless (defined($message->{envelope}->{dataMessage}->{message}));

			check_moduls($message);
	}
}

sub send_messages {
	
	foreach my $send_message (@send_messages) {
		my $cmd = get_signal_cli_path().' -u '.get_bot_number().' send -m "'.$send_message->{message}.'" ';
		if (defined($send_message->{response_to}->{envelope}->{dataMessage}->{groupInfo}->{groupId})) {
			$cmd .= '-g '.$send_message->{response_to}->{envelope}->{dataMessage}->{groupInfo}->{groupId};
		} else {
			$cmd .= $send_message->{response_to}->{envelope}->{source};
		}
		logEntry("führe aus: ".$cmd);
		my $output = `$cmd`;
		
	}

	@send_messages  = ();
}

sub check_moduls {
	my $message = shift;

	modul_statistics($message);
	modul_commands($message);

}


sub modul_commands {
	my $message = shift;
	if ($message->{envelope}->{dataMessage}->{message} =~ m|^/bot (.*)$|) {
		my $commands = [split(" ", $1)];

		command_send_pong($message, $commands) if ($commands->[0] eq 'ping');
		command_send_statistic($message, $commands) if ($commands->[0] eq 'statistik');
		command_set_event_time($message, $commands) if ($commands->[0] eq 'event');
		command_help($message, $commands) if ($commands->[0] eq 'help');
	}
}


sub modul_statistics {
	my $message = shift;

	return unless defined($message->{envelope}->{dataMessage}->{groupInfo}->{groupId});

	$statistic->{$message->{envelope}->{dataMessage}->{groupInfo}->{groupId}}->{$message->{envelope}->{source}}++;
}

sub command_help {
	my $message = shift;
	my $options = shift;


	my $msg = '
	Erstelle neuen Termin:
	/bot event start 21.03.2019 13:33

	Terminliste abruffen:
	/bot event list

	Prüffen ob bot lebt:
	/bot ping

	Statistik abruffen:
	/bot statistik

	Diese Hilfe abruffen:
	/bot help
	';
	push(@send_messages, {message => $msg, response_to => $message});
}

sub command_set_event_time {
	my $message = shift;
	my $options = shift;

	# /bot event

	# Feature is only working in groups
	unless (defined($message->{envelope}->{dataMessage}->{groupInfo}->{groupId})) {
		push(@send_messages, {message => "Events funktioniert leider nur im Gruppenchat...", response_to => $message});
		return;
	}

	#@TODO: validate time :D

	if (scalar(@{$options}) == 2 && $options->[1] eq "list") {
		push(@send_messages, {message => "debug output:".Data::Dumper::Dumper(\@events), response_to => $message});
		return;
	}


	# /bot event start 21.03.2019 13:33

	# temporar injection fix 
	unless (scalar(@{$options}) == 4 && $options->[1] =~ m/[a-z]{1,6}/ && $options->[2] =~ m/\d\d.\d\d.\d\d\d\d/ && $options->[3] =~ m/\d\d:\d\d/) {
		push(@send_messages, {message=> "Event validation error :( nutze dieses format: /bot event start 21.03.2019 13:33", response_to =>$message});
		return;
	}


	my $event_time = Time::Piece->strptime($options->[2]." ".$options->[3]." +0100", "%d.%m.%Y %H:%M %z");
	logEntry("set event time: ".$event_time. " timestamp: ".$event_time->epoch);
	push(@events, {time => $event_time->epoch, event => $options->[1], message => $message});

}

sub command_send_pong {
	push(@send_messages, {message=> "pong", response_to => shift});
}

sub command_send_statistic {
	my $message = shift;

	# @TODO: format the message not only dump array :D
	my $send_message = Data::Dumper::Dumper($statistic->{$message->{envelope}->{dataMessage}->{groupInfo}->{groupId}});
	push(@send_messages, {message=> $send_message, response_to => $message});
}

# Dump of a recived message example from a test groupe
# $VAR1 = {
#           'envelope' => {
#                           'dataMessage' => {
#                                              'attachments' => [],
#                                              'expiresInSeconds' => 0,
#                                              'message' => 'sdf',
#                                              'timestamp' => '1552600377416',
#                                              'groupInfo' => {
#                                                               'groupId' => 'MPSFSRGBGERGBEGRRFSDDeww==',
#                                                               'type' => 'DELIVER',
#                                                               'name' => undef,
#                                                               'members' => undef
#                                                             }
#                                            },
#                           'callMessage' => undef,
#                           'syncMessage' => undef,
#                           'source' => '+1234567890',
#                           'relay' => undef,
#                           'isReceipt' => bless( do{\(my $o = 0)}, 'JSON::PP::Boolean' ),
#                           'sourceDevice' => 3,
#                           'timestamp' => '1552600377416'
#                         }
#         };