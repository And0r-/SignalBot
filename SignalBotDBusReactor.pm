package SignalBotDBusReactor;
use strict;
use warnings;

use Net::DBus;
use Data::Dumper;
use Net::DBus::Reactor;


use Exporter::Easy (OK => [ qw(DBusReactorStart DBusReactorStop) ]);

my $bus = Net::DBus->system;
my $hal = $bus->get_service("org.asamk.Signal");

my $object = $hal->get_object(
    "/org/asamk/Signal",
    "org.asamk.Signal"
);

$object->connect_to_signal('MessageReceived', sub
{
	warn Data::Dumper::Dumper(@_);
	my $timestamp=shift;
	warn $timestamp;
    my $source=shift;
	my $groupID=shift;
	my $message=shift;
    my $attachments=shift;


	warn $message;
	warn $object->getGroupName($groupID);

	$i++;

	$object->sendGroupMessage($i." | ".$message,undef,$groupID);
});


my $reactor = Net::DBus::Reactor->main();
sub start {
	$reactor->run();
}

sub stop {
	$reactor->shutdown();
}