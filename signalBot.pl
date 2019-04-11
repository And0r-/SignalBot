#!/usr/bin/perl -w
use strict;
use warnings;

use JSON;
use Data::Dumper;
use Time::Piece;
use POSIX;
use File::Pid;


require'./logger.pl';
require'./config.pl';
require'./humhub.pl';
require'./signal.pl';




my $json = JSON->new->allow_nonref;

my $statistic = {};
my @events;


sub run_signalBot {
	# Todo: persistent() the data on disk

	mudul_humhub_event_import();

	event_trigger();
	send_messages();
	recive_messages();

 
	# logEntry("log something"); # use this to log whatever you need to
}
 
 
sub event_trigger {

	my $t = localtime;
	my $t_2h_reminder = localtime(time + 2*60*60);

	# event Status:
	# 0 importet
	# 1 noch nicht gestartet
	# 2 angekündigt (remind)
	# 3 gestartet
	# 4 beendet

	foreach my $event_index (0 .. $#events) {
		if ($t->epoch >= $events[$event_index]->{"end"} and $events[$event_index]->{"status"} < 4) {
			add_signal_message("Event endet Jetzt.", $events[$event_index]->{"message"});
			$events[$event_index]->{"status"} = 4;

		} elsif ($t->epoch >= $events[$event_index]->{"start"} and $events[$event_index]->{"status"} < 3) {
			add_signal_message("Event startet Jetzt.", $events[$event_index]->{"message"});
			$events[$event_index]->{"status"} = 3;

		} elsif ($t_2h_reminder->epoch >= $events[$event_index]->{"start"} and $events[$event_index]->{"status"} < 2){
			add_signal_message("REMINDER: Event startet in 2 Stunden", $events[$event_index]->{"message"});
			$events[$event_index]->{"status"} = 2;
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

sub mudul_humhub_event_import {

	my $entrys = get_humhub_calendar();
	
	foreach my $entry (values %{$entrys}) {
		# I don't know the timezone from the user... I need a timezone conzept...
		# At the moment I use the system timezone
		# Save it here as GTM and handle the timezone on the other places will be better in a international project
		my $event_time_start = Time::Piece->strptime($entry->{start_datetime}." ".strftime("%z", localtime()), "%Y-%m-%d %H:%M:%S %z");
		my $event_time_end = Time::Piece->strptime($entry->{end_datetime}." ".strftime("%z", localtime()), "%Y-%m-%d %H:%M:%S %z");

		next if (localtime->epoch >= $event_time_start->epoch);

		my $exist;
		foreach (@events) {
			if ($event_time_start->epoch == $_->{"start"}) {
				$exist = 1;
			}
		}

		unless ($exist) {
			# Better to change to a object, or oly use groupId to answer... now i have to fake a lot, when i will add a event not from the chat :(
			my $fake_message = $json->decode('{"envelope":{"source":"+41794183625","sourceDevice":1,"relay":null,"timestamp":1554337150370,"isReceipt":false,"dataMessage":{"timestamp":1554337150370,"message":"","expiresInSeconds":0,"attachments":[],"groupInfo":{"groupId":"MPDbbB4voiTqNDKlODYeww==","members":null,"name":null,"type":"DELIVER"}},"syncMessage":null,"callMessage":null}}');
			logEntry("set event time: ".$event_time_start. " timestamp: ".$event_time_start->epoch);
			push(@events, {start => $event_time_start->epoch, end => $event_time_end, name => $entry->{title}, status => 0, message => $fake_message});
		}
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
		my $events = "Events:\n";
		foreach (@events) {
			$events .= localtime($_->{start})->strftime('%d.%m.%Y %H:%M')." -> ".$_->{name}."\n";
		}
		add_signal_message($events, $message);
		return;
	}


	# /bot event start 21.03.2019 13:33

	# temporar injection fix 
	unless (scalar(@{$options}) == 4 && $options->[1] =~ m/[a-z]{1,6}/ && $options->[2] =~ m/\d\d.\d\d.\d\d\d\d/ && $options->[3] =~ m/\d\d:\d\d/) {
		add_signal_message("Event validation error :( nutze dieses format: /bot event start 21.03.2019 13:33", $message);
		return;
	}

	# I don't know the timezone from the user... I need a timezone conzept...
	# At the moment I use the system timezone
	# Save it here as GTM and handle the timezone on the other places will be better in a international project
	my $event_time = Time::Piece->strptime($options->[2]." ".$options->[3]." ".strftime("%z", localtime()), "%d.%m.%Y %H:%M %z");

	logEntry("set event time: ".$event_time. " timestamp: ".$event_time->epoch);
	push(@events, {start => $event_time->epoch, end => $event_time->epoch + 2*60*60, status => 0, name => $options->[1], message => $message});

}

sub command_send_pong {
	add_signal_message("pong", shift());
}

sub command_send_statistic {
	my $message = shift;

	# @TODO: format the message not only dump array :D
	my $send_message = "";
	my $groupeId = $message->{envelope}->{dataMessage}->{groupInfo}->{groupId};
	foreach (keys %{$statistic->{$groupeId}}) {
		$send_messages .= resolve_number($_). ": ".$statistic->{$groupeId}->{$_};
	}
	add_signal_message($send_message, $message);
}


sub resolve_number {
	my $user = shift;
	my $resolve_user = get_resolve_user();

	$user = $resolve_user->{$user} if ($resolve_user->{$user});
	return $user;
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