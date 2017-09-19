#!/usr/bin/env perl 
use strict;
use warnings;
use utf8;
use DateTime;

use Getopt::ArgParse;
use Cwd 'abs_path';
use File::Basename;
use Data::Dumper;
use boolean;
use File::Path qw(make_path remove_tree);

use Log::Any qw($log);
use Log::Any::Adapter ('Stdout');

# {{{ createStructDir
sub createStructDir($) {
    my($userName) = @_;
    my($keyFolder, $ContainerPrivateFolder, $mountPrivateFolder);
    if ( $userName eq "root") {
        $keyFolder = "/$userName/keys";
        $ContainerPrivateFolder = "/$userName/.private";
        $mountPrivateFolder = "/$userName/private";
    } else  {
        $keyFolder = "/home/$userName/keys";
        $ContainerPrivateFolder = "/home/$userName/.private";
        $mountPrivateFolder = "/home/$userName/private";
    }

    if (! -d $keyFolder ) { 
        $log->info("create folder keys: $keyFolder");
        my @created = mkpath($keyFolder, 1, 0700);
    }
    if (! -d $ContainerPrivateFolder ) {
        $log->info("create folder containers: $ContainerPrivateFolder ");
        my @created = mkpath($ContainerPrivateFolder, 1, 0700);
    }
    if (! -d $mountPrivateFolder ) { 
        $log->info("create folder private: $mountPrivateFolder");
        my @created = mkpath($mountPrivateFolder, 1, 0700);
    }
}
# }}}

# {{{ createStructDirV2   NEED TEST
sub createStructDirV2($) {
    my($userName) = @_;
    my($keyFolder, $ContainerPrivateFolder, $mountPrivateFolder);
    $keyFolder = "~/.keys";
    $ContainerPrivateFolder = "~/.private";
    $mountPrivateFolder = "~/private";

    if (! -d $keyFolder ) { 
        $log->info("create folder keys: $keyFolder");
        my @created = mkpath($keyFolder, 1, 0700);
    }
    if (! -d $ContainerPrivateFolder ) {
        $log->info("create folder containers: $ContainerPrivateFolder ");
        my @created = mkpath($ContainerPrivateFolder, 1, 0700);
    }
    if (! -d $mountPrivateFolder ) { 
        $log->info("create folder private: $mountPrivateFolder");
        my @created = mkpath($mountPrivateFolder, 1, 0700);
    }
}
# }}}


# {{{dmsetupInfo
sub dmsetupInfo(;$) { 
    my($Name) = @_;
    my(%ret,@listName);
    #if (undef $Name) {  exit(0); }
    my(@outPut) = `dmsetup info $Name`;
    foreach my $val (@outPut) {
        my @spl = split(/:/,$val);
        if ( $spl[0] =~ /[nN][aA][mM][eE]/ ) {
            $spl[1] =~ s/^\s+|\s+$//g;
            push @listName,$spl[1];
        }
    }
    undef @outPut;
    foreach my $name (@listName) {
        @outPut = `dmsetup info $name`;
        pop @outPut;
        my %lllv;
        foreach my $val2 (@outPut) {
            chomp $val2;
            my @spl = split(/:/,$val2);
            foreach my $val3 (@spl) { $val3 =~ s/^\s+|\s+$//g; }
            if ( $spl[0] =~ /Major/ ) {
                my @splArg = split(/,/,$spl[1]);
                foreach my $val3 (@splArg) { $val3 =~ s/^\s+|\s+$//g; }
                $lllv{'Major'} = $splArg[0];
                $lllv{'minor'} = $splArg[1];
                $lllv{'devPath'} = '/dev/dm-' . $splArg[1];
                $lllv{'mapperPath'} = '/dev/mapper/' . $lllv{'Name'};
            } else {
                $lllv{$spl[0]} = $spl[1];
            }
            # print Dumper \%lllv;
        }
        $ret{$name} = \%lllv; 
    }
    print Dumper \%ret;
    return \%ret;
}
# }}}

true;
