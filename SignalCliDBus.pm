package SignalCliDBus;
use strict;
use warnings;

use Net::DBus;
use Net::DBus::Reactor;
use Mojo::Base -base;
use MIME::Base64;
use Data::Dumper;


has reactor => undef;
has signalBot => undef;

has groups => sub {{}};


my $bus = Net::DBus->system;
my $hal = $bus->get_service("org.asamk.Signal");

my $object = $hal->get_object(
    "/org/asamk/Signal",
    "org.asamk.Signal"
);






sub StartReactor {
	my $self = shift;

	$object->connect_to_signal('MessageReceived', sub
	{
		$self->signalBot->MessageReceived(@_);	
	});

	my $reactor = Net::DBus::Reactor->main();
	$self->reactor($reactor);
	$self->reactor->run();
}

sub StopReactor {
	my $self = shift;
	$self->reactor->shutdown();
}


sub sendGroupMessage {
	my $self = shift;
	my $send_message = shift;

	$self->signalBot->logEntry("sende: ".$send_message." an gruppe: ".Data::Dumper::Dumper($self->signalBot->groupID));
	$object->sendGroupMessage($send_message,undef,$self->signalBot->groupID);
	return 1;
}

sub getGroupName {
	my $self = shift;
	return $object->getGroupName($self->signalBot->groupID);
}

sub setGroupIDByName {
	my $self = shift;
	my $name = shift;


	$self->signalBot->groupID($self->getGroupIdByName($name));
	
}

sub getGroupIdByName {
	my $self = shift;
	my $name = shift;

	my $groups = $self->groups;
	return $groups->{$name} if (defined($groups->{$name}));

	# Update known groups
	$groups = {};
	my @groupIds = $object->getGroupIds();
	foreach (@{$groupIds[0]}) {
		$groups->{$object->getGroupName($_)} = $_;
	}

	$self->groups($groups);
	return $groups->{$name} if (defined($groups->{$name}));
	return [];
}

1;