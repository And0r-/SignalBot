#!/usr/bin/perl
use strict;
use warnings;

use LWP::UserAgent ();


# SELECT * FROM calendar_entry ce, content c, contentcontainer cc, space s  WHERE c.object_id = ce.id and c.object_model = 'humhub\\modules\\calendar\\models\\CalendarEntry' and c.contentcontainer_id = cc.id and cc.guid = s.guid and s.name = "Bot Post test"

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

1;