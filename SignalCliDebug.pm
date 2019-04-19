package SignalCliDebug;
use strict;
use warnings;


use Mojo::Base -base;

use MIME::Base64;
use Data::Dumper;

has dieNow => 0;
has signalBot => undef;

sub StartReactor {
	my $self= shift;
	while (!$self->dieNow) {
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

		$self->signalBot->MessageReceived($timestamp,$source,$groupID,$message,$attachments);
	}
	
	truncate 'signal_input.txt', 0 if ($messageFound);

	sleep(3);

	return 1;
}

sub StopReactor {
	shift()->dieNow(1);
}

sub sendGroupMessage {
	my $self=shift;
	warn "send message: ".shift;
}

sub getGroupName {
	my $self = shift;
	return "bot test gruppe";
}

sub setGroupIDByName {
	my $self = shift;
	my $name = shift;

	$self->signalBot->logEntry("groupe name: ".$name);




	my @t = $self->signalBot->getGroups();

$self->signalBot->logEntry("groupe id: ".Data::Dumper::Dumper(\@t));
# 	my @chars = split //, $name;
# 	my @groupId = map ord, @chars;
# 	$self->signalBot->groupID(\@groupId);

# 	$self->signalBot->logEntry("groupe id: ".Data::Dumper::Dumper(\@groupId));


# 	my @string = map chr, @groupId;

# 	$self->signalBot->logEntry("groupe id to chr: ".Data::Dumper::Dumper(\@string));


# 	my $t = [
#           48,
#           240,
#           219,
#           108,
#           30,
#           47,
#           162,
#           36,
#           234,
#           52,
#           50,
#           165,
#           56,
#           54,
#           30,
#           195
#         ];

# my @string2 = map chr, @{$t};
# $self->signalBot->logEntry("groupe id to chr2: ".Data::Dumper::Dumper(\@string2));

}

1;

