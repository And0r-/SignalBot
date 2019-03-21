#!/usr/bin/perl
use strict;
use warnings;

use JSON;
use Data::Dumper;
use Time::Piece;

my $json = JSON->new->allow_nonref;


my $statistic = {};
my @events;
my @events_backup;
my @send_messages;

require'./config.pl';



while (1==1) {

	event_trigger();
	send_messages();
	recive_messages();

}


sub event_trigger {

	my $t = gmtime;

	foreach my $event_index (0 .. $#events) {
		if ($t->epoch >= $events[$event_index]->{"time"}) {
			warn "Event will start now, yeaaay";
			push(@events_backup, $events[$event_index]);
			delete $events[$event_index];
		}
	}
} 

sub recive_messages {
	warn "recive message";
	my $cmd = get_signal_cli_path().' -u '.get_bot_number().' receive --json';
	my $messages = `$cmd`;
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
		warn "führe aus: ".$cmd;
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
	}
}


sub modul_statistics {
	my $message = shift;

	return unless defined($message->{envelope}->{dataMessage}->{groupInfo}->{groupId});

	$statistic->{$message->{envelope}->{dataMessage}->{groupInfo}->{groupId}}->{$message->{envelope}->{source}}++;
}

sub command_set_event_time {
	my $message = shift;
	my $options = shift;
	# /bot event start 21.03.2019 13:33
	warn "event erkannt...";

	# Feature is only working in groups
	unless (defined($message->{envelope}->{dataMessage}->{groupInfo}->{groupId})) {
		push(@send_messages, {message => "Events funktioniert leider nur im Gruppenchat...", response_to => $message});
		return;
	}


	#@TODO: validate time :D

	# temporar injection fix 
	unless (scalar(@{$options}) == 4 && $options->[1] =~ m/[a-z]{1,6}/ && $options->[2] =~ m/\d\d.\d\d.\d\d\d\d/ && $options->[3] =~ m/\d\d:\d\d/) {
		push(@send_messages, {message=> "Event validation error :( nutze dieses format: /bot event start 21.03.2019 13:33", response_to =>$message});
		return;
	}


	my $event_time = Time::Piece->strptime($options->[2]." ".$options->[3]." +0100", "%d.%m.%Y %H:%M %z");
	warn "set event time: ".$event_time. " timestamp: ".$event_time->epoch;
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