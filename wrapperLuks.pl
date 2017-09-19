#!/usr/bin/env perl 
use strict;
use warnings;
use utf8;
use Cwd 'abs_path';
require 'func.pl';
use boolean;

my $view = true;
my $containerName = "def." . time();
my $containerSize = "256";
my $cipher = "aes-xts-plain64";
my $keySize = "512";


my $userName = getpwuid( $< );
print "\$user = $userName\n";

my $absPath = abs_path($0);
print "ABS path: $absPath\n";

#my $uid   = $<;
#print "\$uid = $uid\n";

#dmsetupInfo();
cryptsetupInfo();
