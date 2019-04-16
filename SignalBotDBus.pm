package SignalBotDBus;
use strict;
use warnings;

use Net::DBus;
use Net::DBus::Reactor;
use Mojo::Base 'SignalBot';

has reactor => undef;


my $bus = Net::DBus->system;
my $hal = $bus->get_service("org.asamk.Signal");

my $object = $hal->get_object(
    "/org/asamk/Signal",
    "org.asamk.Signal"
);


$object->connect_to_signal('MessageReceived', sub
{
	$self->MessageReceived(@_);	
});


my $self->reactor = Net::DBus::Reactor->main();


sub StartReactor {
	my $self = shift;
	$self->reactor->run();
}

sub StopReactor {
	my $self = shift;
	$self->reactor->shutdown();
}


sub sendGroupMessage {
	my $self = shift;
	my $send_message = shift;
	$object->sendGroupMessage($send_message,undef,$self->groupID);
	return 1;
}

sub getGroupName {
	my $self = shift;
	return $object->getGroupName($self->groupID);
}

1;