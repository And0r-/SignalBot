#!/usr/bin/perl
use strict;
use warnings;


 my $daemonName    = "signalBot";


my $logging       = 1;                                     # 1= logging is on
my $logFilePath   = "log/";                           # log file path
my $logFile       = $logFilePath . $daemonName . ".log";


# turn on logging
if ($logging) {
	open LOG, ">>$logFile";
	select((select(LOG), $|=1)[0]); # make the log file "hot" - turn off buffering
}

# add a line to the log file
sub logEntry {
	my ($logText) = @_;
	my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) = localtime(time);
	my $dateTime = sprintf "%4d-%02d-%02d %02d:%02d:%02d", $year + 1900, $mon + 1, $mday, $hour, $min, $sec;
	if ($logging) {
		print LOG "$dateTime $logText\n";
		warn "$dateTime $logText\n" if (get_debug());
	}
}

# do this stuff when exit() is called.
END {
	if ($logging) { close LOG }
}


1;