package Timer;
use strict;
use warnings;

use Mojo::Base -base;

has signalBot => undef;
has dieNow => 0;



sub start {
	my $self = shift;

	while (!$self->dieNow) {
		$self->signalBot->logEntry("Timer looooop...");

		sleep(5);
	}
}

sub stop {
	shift()->dieNow(1);
}

1;