package SignalBotDebug;
use strict;
use warnings;
use lib '.';


use Data::Dumper;
use Mojo::Base 'SignalBot';


use Exporter::Easy (OK => [ qw(DebugStart) ]);

my $self = SignalBotDebug->new();
$self->DebugStart;

sub DebugStart {
	my $self= shift;
	while (1) {
		$self->recive_signal_messages_debug();
	}
}

sub recive_signal_messages_debug {
	my $self = shift;
	my $messageFound=0;
	open(my $fh, '<:encoding(UTF-8)', "signal_input.txt");
	while (my $row = <$fh>) {
		chomp $row;

		my $timestamp=1554337150370;
	    my $source='+41794183625';
		my $groupID=[48,240,219,108,30,47,162,36,234,52,50,165,56,54,30,195];
		my $message=$row;
    	my $attachments=undef;
		$messageFound=1;

		$self->MessageReceived($timestamp,$source,$groupID,$message,$attachments);
	}
	
	truncate 'signal_input.txt', 0 if ($messageFound);

	sleep(3);

	return 1;
}


sub sendGroupMessage {
	my $self=shift;
	warn "send message: ".shift;
}

1;
