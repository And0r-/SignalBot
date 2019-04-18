package Timer;
use strict;
use warnings;

use Mojo::Base -base;
use Time::Piece;

has signalBot => undef;
has dieNow => 0;



sub start {
	my $self = shift;

	while (!$self->dieNow) {
		# $self->signalBot->logEntry("Timer looooop...");
		$self->event_trigger;
		$self->signalBot->mudul_humhub_event_import;


		sleep(5);
	}
}

sub stop {
	shift()->dieNow(1);
}


# move to modul/event.pm
sub event_trigger {
	my $self = shift;

	my $t = localtime;
	my $t_2h_reminder = localtime(time + 2*60*60);

	$self->signalBot->signal_cli->setGroupIDByName("bot test gruppe");
	$self->signalBot->logEntry("groupe name: ".$self->signalBot->signal_cli->getGroupName);

	$self->signalBot->logEntry("Reminder timestamp: ".$t_2h_reminder->epoch);
	my $events = $self->signalBot->mysql_get_events;

	# event Status:
	# 0 importet
	# 1 noch nicht gestartet
	# 2 angekündigt (remind)
	# 3 gestartet
	# 4 beendet

	foreach my $event (values %{$events}) {
		$self->signalBot->logEntry("start time: ".$event->{"start_time"}. " status: ".$event->{"status"});
		
		if ($t->epoch >= $event->{"end_time"} and $event->{"status"} < 4) {
			$self->signalBot->signal_cli->sendGroupMessage("Event endet Jetzt.");
			$event->{"status"} = 4;

		} elsif ($t->epoch >= $event->{"start_time"} and $event->{"status"} < 3) {
			$self->signalBot->signal_cli->sendGroupMessage("Event startet Jetzt.");
			$self->mysql_update_event_status($event->{id},3);

		} elsif ($t_2h_reminder->epoch >= $event->{"start_time"} and $event->{"status"} < 2){
			$self->signalBot->signal_cli->sendGroupMessage("REMINDER: Event startet in 2 Stunden");
			$self->mysql_update_event_status($event->{id},2);
		}
	}
} 

# move to modul/event.pm
sub mysql_update_event_status {
	my $self = shift;
	my $event_id = shift;
	my $status = shift;

	$self->signalBot->dbh->do("
            UPDATE
                event
            SET
                status = ?
            WHERE
            	id = ?;
        ", undef,
        (
            $status,
            $event_id
        ),
    );
}
1;


