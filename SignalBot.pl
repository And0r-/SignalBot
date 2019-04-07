#!/usr/bin/perl -w
use strict;
use warnings;

use JSON;
use Data::Dumper;
use Time::Piece;
use POSIX;
use File::Pid;



require'./config.pl';
require'./humhub.pl';
require'./signal.pl';


my $dieNow        = 0;                                     # used for "infinte loop" construct - allows daemon mode to gracefully exit
my $json = JSON->new->allow_nonref;

my $statistic = {};
my @events;
my @events_backup;



sub run_signalBot {
	 
	# "infinite" loop where some useful process happens
	until ($dieNow) {
	 
		# Todo: persistent() the data on disk

		event_trigger();
		send_messages();
		recive_messages();
	 
		# logEntry("log something"); # use this to log whatever you need to
	}
}
 
 
sub event_trigger {

	my $t = localtime;
	my $t_2h_reminder = localtime(time + 2*60*60);

	foreach my $event_index (0 .. $#events) {
		if ($t->epoch >= $events[$event_index]->{"time"}) {
			add_signal_message("Event Startet Jetzt", $events[$event_index]->{"message"});

			push(@events_backup, $events[$event_index]);
			delete $events[$event_index];
		} elsif ($t_2h_reminder->epoch >= $events[$event_index]->{"time"} && !$events[$event_index]->{"2h_reminder_done"}){
			$events[$event_index]->{"2h_reminder_done"} = 1;
			add_signal_message("REMINDER: Event startet in 2 Stunden", $events[$event_index]->{"message"});
		}
	}
} 

sub recive_messages {
	
	my $messages = recive_signal_messages();
	return unless ($messages);

	foreach my $message (@{$messages}) {
			$message = $json->decode( $message );

			# There is a lot of background messages. when a user recive a message to say i get this on this device... Ignore it at the moment
			next unless (defined($message->{envelope}->{dataMessage}->{message}));

			check_moduls($message);
	}
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
		command_humhub_post($message, $commands) if ($commands->[0] eq 'post');
	}
}

sub modul_statistics {
	my $message = shift;

	return unless defined($message->{envelope}->{dataMessage}->{groupInfo}->{groupId});

	$statistic->{$message->{envelope}->{dataMessage}->{groupInfo}->{groupId}}->{$message->{envelope}->{source}}++;
}

sub command_humhub_post {
	my $message = shift;
	my $options = shift;

	my $error = humhub_post("Message from Perl script. es funktioniert :) yeaaa");
	add_signal_message("Leider konnte der post nicht erstellt werden: $error", $message) unless $error;
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
	add_signal_message($msg, $message);
}

sub command_set_event_time {
	my $message = shift;
	my $options = shift;

	# /bot event

	# Feature is only working in groups
	unless (defined($message->{envelope}->{dataMessage}->{groupInfo}->{groupId})) {
		add_signal_message("Events funktioniert leider nur im Gruppenchat...", $message);
		return;
	}

	#@TODO: validate time :D

	if (scalar(@{$options}) == 2 && $options->[1] eq "list") {
		add_signal_message("debug output:".Data::Dumper::Dumper(\@events), $message);
		return;
	}


	# /bot event start 21.03.2019 13:33

	# temporar injection fix 
	unless (scalar(@{$options}) == 4 && $options->[1] =~ m/[a-z]{1,6}/ && $options->[2] =~ m/\d\d.\d\d.\d\d\d\d/ && $options->[3] =~ m/\d\d:\d\d/) {
		add_signal_message("Event validation error :( nutze dieses format: /bot event start 21.03.2019 13:33", $message);
		return;
	}


	my $event_time = Time::Piece->strptime($options->[2]." ".$options->[3]." +0100", "%d.%m.%Y %H:%M %z");
	logEntry("set event time: ".$event_time. " timestamp: ".$event_time->epoch);
	push(@events, {time => $event_time->epoch, event => $options->[1], message => $message});

}

sub command_send_pong {
	add_signal_message("pong", shift());
}

sub command_send_statistic {
	my $message = shift;

	# @TODO: format the message not only dump array :D
	my $send_message = Data::Dumper::Dumper($statistic->{$message->{envelope}->{dataMessage}->{groupInfo}->{groupId}});
	add_signal_message($send_message, $message);
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
1;