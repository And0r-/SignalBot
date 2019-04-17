package SignalBot;
use strict;
use warnings;

use Data::Dumper;
use Mojo::Base 'SignalBotHelper';

use Time::Piece;
use POSIX;

has message => undef;
has groupID => undef;
has source => undef;


my @events;



sub MessageReceived {
	my $self= shift;
	my $timestamp=shift;
    $self->source(shift());
	$self->groupID(shift());
	$self->message(shift());
    my $attachments=shift;

	

	$self->check_moduls;

	return;
}

sub check_moduls {
	my $self = shift;

	$self->modul_statistics;
	$self->modul_commands;
}

sub modul_commands {
	my $self = shift;
	if ($self->message =~ m|^/bot (.*)$|) {
		my $commands = [split(" ", $1)];

		$self->command_send_pong($commands) if ($commands->[0] eq 'ping');
		$self->command_send_statistic($commands) if ($commands->[0] eq 'statistik');
		$self->command_set_event_time($commands) if ($commands->[0] eq 'event');
		$self->command_help($commands) if ($commands->[0] eq 'help');
		$self->command_humhub_post($commands) if ($commands->[0] eq 'post');
	}
}

sub modul_statistics {
	my $self = shift;

	$self->dbh->do( "
            INSERT
                signalBot.statistic
            SET
                groupe = ?,
                user = ?;
        ", undef,
        (
            $self->signal_cli->getGroupName,
            $self->source,
        ),
    );
}



sub command_humhub_post {
	my $self = shift;
	my $options = shift;

	# my $error = humhub_post("Message from Perl script. es funktioniert :) yeaaa");
	# add_signal_message("Leider konnte der post nicht erstellt werden: $error", $message) unless $error;
}

sub command_help {
	my $self = shift;
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
	$self->signal_cli->sendGroupMessage($msg);
}

sub command_set_event_time {
	my $self = shift;
	my $options = shift;

	# /bot event

	# @TODO: Nach umwandlung der struktur macht das keinen sinn... send message to single user :D
	# Feature is only working in groups
	unless (defined($self->groupID)) {
		$self->signal_cli->sendGroupMessage("Events funktioniert leider nur im Gruppenchat...");
		return;
	}

	#@TODO: validate time :D

	#@TODO: at the moment Events can not be set

	if (scalar(@{$options}) == 2 && $options->[1] eq "list") {
		my $events = "Events:\n";
		foreach (@events) {
			$events .= localtime($_->{start})->strftime('%d.%m.%Y %H:%M')." -> ".$_->{name}."\n";
		}
		$self->signal_cli->sendGroupMessage($events);
		return;
	}


	# /bot event start 21.03.2019 13:33

	# temporar injection fix 
	unless (scalar(@{$options}) == 4 && $options->[1] =~ m/[a-z]{1,6}/ && $options->[2] =~ m/\d\d.\d\d.\d\d\d\d/ && $options->[3] =~ m/\d\d:\d\d/) {
		$self->signal_cli->sendGroupMessage("Event validation error :( nutze dieses format: /bot event start 21.03.2019 13:33");
		return;
	}

	# I don't know the timezone from the user... I need a timezone conzept...
	# At the moment I use the system timezone
	# Save it here as GTM and handle the timezone on the other places will be better in a international project
	my $event_time = Time::Piece->strptime($options->[2]." ".$options->[3]." ".strftime("%z", localtime()), "%d.%m.%Y %H:%M %z");

	$self->logEntry("set event time: ".$event_time. " timestamp: ".$event_time->epoch);
	push(@events, {start => $event_time->epoch, end => $event_time->epoch + 2*60*60, status => 0, name => $options->[1], message => $self->message});

}

sub command_send_pong {
	shift()->signal_cli->sendGroupMessage("pong");
}

sub command_send_statistic {
	my $self = shift;


    
    my $statistic =
    $self->dbh->selectall_hashref( '
            select user, count(user) as count from statistic where time>=? and time<=? and groupe = ? GROUP by user;
        ',
        'user',
        undef,
        (
        	'2011-03-17 06:42:10',
        	'2020-03-17 07:42:50',
        	$self->signal_cli->getGroupName
        ) 
     );
      

    
	my $send_message = "Geschriebene Nachrichten:\n";
	foreach (sort {$statistic->{$b}->{count} cmp $statistic->{$a}->{count}}keys %{$statistic}) {
		$send_message .= $self->resolve_number($_). ": ".$statistic->{$_}->{count}."\n";
	}
	$self->signal_cli->sendGroupMessage($send_message);
}


sub resolve_number {
	my $self = shift;
	my $user = shift;
	my $resolve_user = $self->config->resolveUser;

	$user = $resolve_user->{$user} if ($resolve_user->{$user});
	return $user;
}

1;