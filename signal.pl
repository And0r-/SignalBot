#!/usr/bin/perl
use strict;
use warnings;

require'./config.pl';
require'./logger.pl';

my @send_messages;

sub add_signal_message {
	my $message = shift;
	my $response_to = shift;
	push(@send_messages, {message => $message, response_to => $response_to});
	return;
}

sub send_messages {
	foreach my $send_message (@send_messages) {
		my $cmd = get_signal_cli_path().' -u '.get_bot_number().' send -m "'.$send_message->{message}.'" ';
		if (defined($send_message->{response_to}->{envelope}->{dataMessage}->{groupInfo}->{groupId})) {
			$cmd .= '-g '.$send_message->{response_to}->{envelope}->{dataMessage}->{groupInfo}->{groupId};
		} else {
			$cmd .= $send_message->{response_to}->{envelope}->{source};
		}
		my $output = exec_command($cmd);
	}
	@send_messages  = ();
	return;
}

sub recive_signal_messages {
	logEntry("recive message");
	return recive_signal_messages_debug() if (get_debug());
	my $messages = "";
	my $cmd = get_signal_cli_path().' -u '.get_bot_number().' receive -t 3 --json';
	$messages = exec_command($cmd);

	return unless ($messages);
	# Multiple messages are spitet by new line

	return [ split(/\n/, $messages) ];
}

sub recive_signal_messages_debug {
	my @lines;
	open(my $fh, '<:encoding(UTF-8)', "signal_input.txt");
	while (my $row = <$fh>) {
		chomp $row;
		$row = '{"envelope":{"source":"+41794183625","sourceDevice":1,"relay":null,"timestamp":1554337150370,"isReceipt":false,"dataMessage":{"timestamp":1554337150370,"message":"'.$row.'","expiresInSeconds":0,"attachments":[],"groupInfo":{"groupId":"MPDbbB4voiTqNDKlODYeww==","members":null,"name":null,"type":"DELIVER"}},"syncMessage":null,"callMessage":null}}';
		push(@lines, $row);
	}
	
	truncate 'signal_input.txt', 0 if (scalar @lines > 0);

	sleep(3);

	return \@lines;
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

sub exec_command {
	my $cmd = shift;
	if (get_debug()) {
		logEntry("when debug is off, run this command: ".$cmd);
		return "";
	} else {
		return `$cmd`;
	}
}

1;