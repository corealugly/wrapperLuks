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
    my($keyFolder, $containerPrivateFolder, $mountPrivateFolder);
    if ( $userName eq "root") {
        $keyFolder = "/$userName/keys";
        $containerPrivateFolder = "/$userName/.private";
        $mountPrivateFolder = "/$userName/private";
    } else  {
        $keyFolder = "/home/$userName/keys";
        $containerPrivateFolder = "/home/$userName/.private";
        $mountPrivateFolder = "/home/$userName/private";
    }

    if (! -d $keyFolder ) { 
        $log->info("create folder keys: $keyFolder");
        my @created = mkpath($keyFolder, 1, 0700);
    }
    if (! -d $containerPrivateFolder ) {
        $log->info("create folder containers: $containerPrivateFolder ");
        my @created = mkpath($containerPrivateFolder, 1, 0700);
    }
    if (! -d $mountPrivateFolder ) { 
        $log->info("create folder private: $mountPrivateFolder");
        my @created = mkpath($mountPrivateFolder, 1, 0700);
    }
    return $keyFolder, $containerPrivateFolder, $mountPrivateFolder;
}
# }}}

# {{{ createStructDirV2   NEED TEST
sub createStructDirV2() {
    my($keyFolder, $containerPrivateFolder, $mountPrivateFolder);
    $keyFolder = "~/.keys";
    $containerPrivateFolder = "~/.private";
    $mountPrivateFolder = "~/private";

    if (! -d $keyFolder ) { 
        $log->info("create folder keys: $keyFolder");
        my @created = mkpath($keyFolder, 1, 0700);
    }
    if (! -d $containerPrivateFolder ) {
        $log->info("create folder containers: $containerPrivateFolder ");
        my @created = mkpath($containerPrivateFolder, 1, 0700);
    }
    if (! -d $mountPrivateFolder ) { 
        $log->info("create folder private: $mountPrivateFolder");
        my @created = mkpath($mountPrivateFolder, 1, 0700);
    }
    return $keyFolder, $containerPrivateFolder, $mountPrivateFolder;
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
    #print Dumper \%ret;
    return \%ret;
}
# }}}

# {{{ createFileContainer  NEED TEST
sub createFileContainer($$$;$) {
    my($containerPrivateFolder, $containerName, $containerSize, $bs) = @_;
    if ( not defined $bs ) { $bs = "1M" }

    if ( -d $containerPrivateFolder ) {
        my $containerPath = $containerPrivateFolder . "/" . $containerName . ".crt";
        $containerPath =~ s/\/\//\//g;
        print "containerPath: " . $containerPath;
        if ( ! -e $containerPath ) { 
            my @outPut = `dd if=/dev/urandom of=$containerPath bs=$bs count=$containerSize status=progres`;
            print Dumper \@outPut;
            return $containerPath;
        } else { $log->error("containerPath is exist: $containerPath"); }
    } else { $log->error("containerPrivateFolder not exist: $containerPrivateFolder"); }
}
# }}}

# {{{ createKeyFile NEED TEST
sub createKeyFile($$$) {
    my($keyFolder, $containerName, $keySize) = @_;

    if ( -d $keyFolder ) {
        my $keyPath = $keyFolder . "/" . $containerName . ".key";
        $keyPath =~ s/\/\//\//g;
        print "keyPath: " . $keyPath;
        if ( ! -e $keyPath ) { 
            my @outPut = `dd if=/dev/urandom of=$keyPath bs=${keySize} count=1 status=progres`;
            print Dumper \@outPut;
            return $keyPath;
        } else { $log->error("KeyPath is exist: $keyPath"); }
    } else { $log->error("keyFolder not exist: $keyFolder"); }
   
}
# }}}

# {{{ formatLuksDevice NEED TEST
sub formatLuksDevice($$$$) {
    my($containerPath, $keyPath, $cipher, $keySize) = @_;

    if ( -e $containerPath ) {
        if ( -e $keyPath ) { 
            my @outPut = `cryptsetup luksFormat $containerPath -d $keyPath -c $cipher -s $keySize`;
        } else { $log->error("keyPath not exist: $keyPath"); }
    } else { $log->error("containerPath not exist: $containerPath");}
}
# }}}

# {{{ cryptsetupInfo 
sub cryptsetupInfo(;$) {
    my($Name) = @_;
    my(%ret,$lllv);

    $lllv = dmsetupInfo();
    my %mpdc;
    foreach my $key (keys %$lllv) {
        my @outPut = `cryptsetup status $key`;
        if ($? == 0 ) { 
            LINE: foreach my $val (@outPut) {
                chomp $val;
                my @spl = split(/:/,$val);
                if ( $#spl == 0 ) {
                    my @spl2 = split(/ /,$val);
                    $mpdc{'mapperPath'} = $spl2[0];
                    next LINE;
                }
                foreach my $val2 (@spl) { $val2 =~ s/^\s+|\s+$//g; }
                $mpdc{"$spl[0]"} = $spl[1];
            $ret{"$key"} = \%mpdc;
            }
        }
        #print "exit code: $?" . "\n";
    }
    #print Dumper \%ret;
    return \%ret;
}
# }}}

# {{{ openLuksDevice NEED TEST
sub openLuksDevice($$$) {
    my($containerName, $containerPath, $keyPath) = @_;

    if ( -e $containerPath ) {
        if ( -e $keyPath ) { 
            #my($containerName, $directories, $suffix) = fileparse($containerPath);
            my @outPut = `cryptsetup luksOpen $containerPath -d $keyPath  $containerName`;
        } else { $log->error("keyPath not exist: $keyPath"); }
    } else { $log->error("containerPath not exist: $containerPath");}
}
# }}}

# {{{ createFsDevice  NEED TEST
sub createFsDevice($$) {
    my($fsName,$pathDevice) = @_;
    my $fsComm;
    my %fsHash = (                 # ADD new FS with params
        "reiserfs" => "mkreiserfs",
        "ext4"     => "mkfs.ext4"
    );

    if ( -e $pathDevice ) {
        $fsComm = $fsHash{$fsName};
        if ( ! defined $fsComm) { $log->error("fs not exist: $fsComm"); return -1;  }
    } else { $log->error("device not exist: $pathDevice"); return -1; }
 
    my @outPut = `env $fsComm $pathDevice`;
    return $?;
}
# }}}

# {{{ mountFsDevice  NEED TEST
sub mountFsDevice($$;$) {
    my($pathDevice, $mountPoint, $userName) = @_;
    my @outPut;

    if ( -e $pathDevice ) {
        if ( -d $mountPoint ) {
             @outPut = `env mount $pathDevice $mountPoint`;
            if ( $? == 0 and defined $userName) {
                @outPut = `chown -hR $userName:$userName $mountPoint`;
                return $?;
            }
            return $?;
        } else { $log->error("mount point not exist: $mountPoint"); return -1; }
    } else { $log->error("device not exist: $pathDevice"); return -1; }
}
# }}}

true;
