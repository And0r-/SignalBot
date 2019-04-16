package SignalBot;
use strict;
use warnings;
use lib '.';

use Data::Dumper;
use Mojo::Base -base;


my $i=0;


sub MessageReceived {
	my $self= shift;
	warn Data::Dumper::Dumper(@_);
	my $timestamp=shift;
    my $source=shift;
	my $groupID=shift;
	my $message=shift;
    my $attachments=shift;


	warn $message;
	# warn $object->getGroupName($groupID);

	$i++;

	warn $i;
	$self->sendGroupMessage($message,undef,$groupID);

	# $object->sendGroupMessage($i." | ".$message,undef,$groupID);

	return;
}

1;