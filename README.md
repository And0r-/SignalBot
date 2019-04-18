# SignalBot
first try to create a small Signal Bot in Perl with signal_cli (https://github.com/AsamK/signal-cli)

copy the config.pl.orig to config.pl and add your personal stuff

signal_cli has to be registerd and be working


functions done
ping pong:
/bot ping -> returns pong

statistics:
each message on a groupe will be counted on the background
/bot statistic -> returns a message count for all active numbers
this will be used for events. after a meeting it will be posted and exported to humhub


functions comming soon:
event:
set a meeting time.
1h before there will be sent a reminder.
on time, the statistics will be resettet and a opening messige sent to the groupe

persistance:
at the moment when you restart the bot, every statistic and event will be lost.
Store it on a file, or database

export:
/bot export <message> should be postet from the bot in a humhub space

aliases:
each bot command should be able with a alias. e.g. /^abc:/ instead of /bot export 


to easy start/stop all services, add this to bash alias file:
function s() { sudo /etc/init.d/signalBot $@; sudo /etc/init.d/signalBotTimer $@; }
so you can use "s start" or "s stop"
