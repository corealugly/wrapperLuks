#!/usr/bin/env perl 
#===============================================================================
#
#         FILE: wrapperLuks.pl
#
#        USAGE: ./wrapperLuks.pl  
#
#  DESCRIPTION: 
#
#      OPTIONS: ---
# REQUIREMENTS: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: corealugly, 
# ORGANIZATION: 
#      VERSION: 1.0
#      CREATED: 08/08/2017 11:01:01 PM
#     REVISION: ---
#===============================================================================

use strict;
use warnings;
use utf8;
use Cwd 'abs_path';
require 'func.pl';
use Sudo;


my $user = getpwuid( $< );
print "\$user = $user\n";

my $absPath = abs_path($0);
print "ABS path: $absPath\n";

#my $uid   = $<;
#print "\$uid = $uid\n";

dmsetupInfo();

