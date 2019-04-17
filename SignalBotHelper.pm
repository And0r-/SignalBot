package SignalBotHelper;
use strict;
use warnings;

use Mojo::Base -base;

use SignalConfig;
use LWP::UserAgent ();
use DBI;


has config  => sub { SignalConfig->new };
has dbh => undef;

my $daemonName    = "signalBot";


my $logging       = 1;                                     # 1= logging is on
my $logFilePath   = "log/";                           # log file path
my $logFile       = $logFilePath . $daemonName . ".log";


# CLAF... bether to load this automatic on creating the object. but i do not find a way to get acces there to the config...
# @TODO das geht besser :)
sub init_dbi {
	my $self = shift;
	my $dbh = DBI->connect($self->config->mysql_dns, $self->config->mysql_user, $self->config->mysql_pw);
	$dbh->do("USE 19915268_firestorm_humhub;");
	$dbh->do('SET NAMES \'utf8\'');
	$dbh->do('SET CHARACTER SET \'utf8\'');
	$dbh->{mysql_auto_reconnect} = 1;
	$self->dbh($dbh);
}




# turn on logging
if (SignalConfig->new->fileLogs) {
	open LOG, ">>$logFile";
	select((select(LOG), $|=1)[0]); # make the log file "hot" - turn off buffering
}

# add a line to the log file
sub logEntry {
	my $self=shift;
	my ($logText) = @_;
	my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) = localtime(time);
	my $dateTime = sprintf "%4d-%02d-%02d %02d:%02d:%02d", $year + 1900, $mon + 1, $mday, $hour, $min, $sec;
	print LOG "$dateTime $logText\n" if ($self->config->fileLogs);
	warn "$dateTime $logText\n" if ($self->config->warnLogs);
}

# do this stuff when exit() is called.
END {
	if (SignalConfig->new->fileLogs) { close LOG }
}





sub getHumhubCalendar {
	my $self = shift;

 	my $sql = 'SELECT ce.* FROM calendar_entry ce, content c, contentcontainer cc, space s  WHERE  c.object_id = ce.id and c.object_model = "humhub\\\\modules\\\\calendar\\\\models\\\\CalendarEntry" and c.contentcontainer_id = cc.id and cc.guid = s.guid and s.name = ?';

    my $result = $self->dbh->selectall_hashref(
        $sql
        ,
        'id',
        undef,
        ( "Bot Post test" ) );

    return $result;

}


sub humhub_post {
	my $msg = shift;
	# setup UserAgent
	my $ua = LWP::UserAgent->new(ssl_opts => { verify_hostname => 1 });
	$ua->timeout(10);
	$ua->env_proxy;
	$ua->cookie_jar( {} );
	push @{ $ua->requests_redirectable }, 'POST';
	 
	# Get Loginform (we need a token)
	my $response = $ua->get('https://ritualspace.quadmonah.ch');
	return $response->status_line unless ($response->is_success); # Return when error

	# POST login
	my $login_form = {"_csrf" => _humhub_extract_csrf_token($response->decoded_content), "Login[username]" => get_humhub_user(), "Login[password]" => get_humhub_pw(), "Login[rememberMe]" => 0};
	$response = $ua->post("https://ritualspace.quadmonah.ch/user/auth/login", $login_form );
	return $response->status_line unless ($response->is_success); # Return when error


	# POST message
	my $post_form = {"_csrf" => _humhub_extract_csrf_token($response->decoded_content), "message" => $msg, "containerGuid" => "6787f49c-9b88-4f19-a6ec-2324e3265ea4", "containerClass" => 'humhub\modules\space\models\Space'};
	$response = $ua->post("https://ritualspace.quadmonah.ch/s/bot-post-test/post/post/post", $post_form );
	return $response->status_line unless ($response->is_success); # Return when error
	return "";
}


sub _humhub_extract_csrf_token {
	shift() =~ m/\<meta name="csrf-token" content="(.*?)"\>/gi;
	return $1;
}