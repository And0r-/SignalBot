#!/usr/bin/perl -w
use strict;
use warnings;
use lib '.';

use SignalBot;


SignalBot->new()->init->signal_cli->StartReactor;

 

