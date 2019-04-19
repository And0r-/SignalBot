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
                statistic
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

# move to modul/event.pm
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


	if (scalar(@{$options}) == 2 && $options->[1] eq "list") {
		my $events = $self->mysql_get_events;



		my $events_msg = "Events der nächsten 14 Tage:\n";
		foreach (values %{$events}) {
			$events_msg .= localtime($_->{start_time})->strftime('%d.%m.%Y %H:%M')." - ".localtime($_->{end_time})->strftime('%d.%m.%Y %H:%M')." -> ".$_->{name}."\n";
		}
		$self->signal_cli->sendGroupMessage($events_msg);
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

	$self->logEntry("create event: ".$event_time. " timestamp: ".$event_time->epoch);


	$self->dbh->do("
            INSERT
                event
            SET
                groupe = ?,
                start_time = FROM_UNIXTIME(?),
                end_time = FROM_UNIXTIME(?),
                name = ?;
        ", undef,
        (
            $self->signal_cli->getGroupName,
            $event_time->epoch,
            $event_time->epoch + 2*60*60,
            $options->[1],
        ),
    );

}

# move to modul/event.pm
sub mysql_get_events {
	my $self = shift;
	return $self->dbh->selectall_hashref( '
	            select id, UNIX_TIMESTAMP(start_time) as start_time, UNIX_TIMESTAMP(end_time) as end_time, name, status from event where groupe = ? AND ((start_time >= NOW() - INTERVAL 2 DAY AND start_time  < NOW() + INTERVAL 14 DAY) OR start_time < NOW() AND end_time > NOW());
	        ',
	        'id',
	        undef,
	        (
	        	$self->signal_cli->getGroupName
	        ) 
	     );
}

# move to modul/event.pm and merge with mysql_get_events
sub mysql_get_all_upcomming_humhub_events {
	my $self = shift;
	return $self->dbh->selectall_hashref( '
	            select id, humhub_id, UNIX_TIMESTAMP(start_time) as start_time, UNIX_TIMESTAMP(end_time) as end_time, name, status from event where groupe = ? AND humhub_id > 0 AND ((start_time >= NOW() - INTERVAL 2 DAY) OR start_time < NOW() AND end_time > NOW());
	        ',
	        'id',
	        undef,
	        (
	        	$self->signal_cli->getGroupName
	        ) 
	     );
}

sub mudul_humhub_event_import {
	my $self = shift;

	my $entrys = $self->mysql_humhub_calendar;
	my $events = $self->mysql_get_all_upcomming_humhub_events;

	my $existing_events = {};
	foreach (values %{$events}){
		$existing_events->{$_->{start_time}.$_->{end_time}.$_->{name}.$_->{humhub_id}} = 1;
	}
	
	foreach my $entry (values %{$entrys}) {

		# I don't know the timezone from the user... I need a timezone conzept...
		# At the moment I use the system timezone
		# Save it here as GTM and handle the timezone on the other places will be better in a international project
		my $event_time_start = Time::Piece->strptime($entry->{start_datetime}." ".strftime("%z", localtime()), "%Y-%m-%d %H:%M:%S %z");
		my $event_time_end = Time::Piece->strptime($entry->{end_datetime}." ".strftime("%z", localtime()), "%Y-%m-%d %H:%M:%S %z");

		# do not import old events
		next if (localtime->epoch >= $event_time_start->epoch);

		# Exist this event with exact the same data
		next if (defined ($existing_events->{$event_time_start->epoch.$event_time_end->epoch.$entry->{title}.$entry->{id}}));


		# Better to change to a object, or oly use groupId to answer... now i have to fake a lot, when i will add a event not from the chat :(
		$self->logEntry("set event time: ".$event_time_start. " timestamp: ".$event_time_start->epoch);

		$self->dbh->do("
            REPLACE INTO
                event
            SET
                groupe = ?,
                start_time = FROM_UNIXTIME(?),
                end_time = FROM_UNIXTIME(?),
                name = ?,
                humhub_id = ?;
	        ", undef,
	        (
	            "bot test gruppe",
	            $event_time_start->epoch,
	            $event_time_end->epoch,
	            $entry->{title},
	            $entry->{id}
	        ),
    	);
	}
}

sub mysql_humhub_calendar {
	my $self = shift;

 	my $sql = 'SELECT ce.* FROM calendar_entry ce, content c, contentcontainer cc, space s  WHERE  c.object_id = ce.id and c.object_model = "humhub\\\\modules\\\\calendar\\\\models\\\\CalendarEntry" and c.contentcontainer_id = cc.id and cc.guid = s.guid and s.name = ? AND ((start_datetime >= NOW() - INTERVAL 2 DAY) OR start_datetime < NOW() AND end_datetime > NOW())';

    my $result = $self->dbh_humhub->selectall_hashref(
        $sql
        ,
        'id',
        undef,
        ( "Bot Post test" ) );

    return $result;
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