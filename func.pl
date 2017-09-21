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
use File::Path qw(make_path mkpath remove_tree);

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

# {{{ createStructDirV2 
sub createStructDirV2() {
    my($keyFolder, $containerPrivateFolder, $mountPrivateFolder, $homeDir);
    $homeDir =  $ENV{'HOME'};
    print "homedir: " . $homeDir . "\n"; 
    $keyFolder = $homeDir . "/.keys";
    $containerPrivateFolder = $homeDir . "/.private";
    $mountPrivateFolder = $homeDir . "/private";

    $log->info("-- Create folder structure --");
    if (! -d $keyFolder ) { 
        my @created = make_path($keyFolder, {  verbose => 0, mode => 0700 });
        $log->info("create folder keys: $keyFolder");
    } else { $log->info("folder of keys is exist: $keyFolder"); }
    if (! -d $containerPrivateFolder ) {
        my @created = make_path($containerPrivateFolder, { verbose => 0, mode => 0700 });
        $log->info("create folder containers: $containerPrivateFolder ");
    } else { $log->info("folder of containers is exist: $containerPrivateFolder "); }
    if (! -d $mountPrivateFolder ) { 
        my @created = make_path($mountPrivateFolder, { verbose => 0, mode => 0700 });
        $log->info("create folder private: $mountPrivateFolder");
    } else { $log->info("private folder is exist: $mountPrivateFolder"); }
    $log->info("---------------------------");
    return($keyFolder, $containerPrivateFolder, $mountPrivateFolder);
}
# }}}

# {{{dmsetupInfo
sub dmsetupInfo(;$) { 
    my($Name) = @_;
    my(%ret,@listName);
    #if (undef $Name) {  exit(0); }
    my(@outPut) = `sudo dmsetup info $Name`;
    foreach my $val (@outPut) {
        my @spl = split(/:/,$val);
        if ( $spl[0] =~ /[nN][aA][mM][eE]/ ) {
            $spl[1] =~ s/^\s+|\s+$//g;
            push @listName,$spl[1];
        }
    }
    undef @outPut;
    foreach my $name (@listName) {
        @outPut = `sudo dmsetup info $name`;
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

# {{{ createFileContainer  
sub createFileContainer($$$;$) {
    my($containerPrivateFolder, $containerName, $containerSize, $bs) = @_;
    if ( not defined $bs ) { $bs = "1M" }

    if ( -d $containerPrivateFolder ) {
        my $containerPath = $containerPrivateFolder . "/" . $containerName . ".crt";
        $containerPath =~ s/\/\//\//g;
        if ( ! -e $containerPath ) { 
            $log->info("-- Create container --");
            my @outPut = `dd if=/dev/urandom of=$containerPath bs=$bs count=$containerSize status=progress`;
            $log->info("containerPath: $containerPath");
            $log->info("---------------------------");
            #print Dumper \@outPut;
            return $containerPath;
        } else { 
            $log->error("containerPath is exist: $containerPath");
            return $containerPath;
          }
    } else { 
        $log->error("containerPrivateFolder not exist: $containerPrivateFolder"); }
        return false;
}
# }}}

# {{{ createKeyFile 
sub createKeyFile($$$) {
    my($keyFolder, $containerName, $keySize) = @_;

    if ( -d $keyFolder ) {
        my $keyPath = $keyFolder . "/" . $containerName . ".key";
        $keyPath =~ s/\/\//\//g;
        if ( ! -e $keyPath ) { 
            $log->info("-- Create key --");
            my @outPut = `dd if=/dev/urandom of=$keyPath bs=${keySize} count=1 status=progress`;
            $log->info("keyPath: $keyPath");
            $log->info("---------------------------");
            #print Dumper \@outPut;
            return $keyPath;
        } else { 
            $log->error("KeyPath is exist: $keyPath");
            return $keyPath; 
          }
    } else { 
        $log->error("keyFolder not exist: $keyFolder");
        return -1;
      }
   
}
# }}}

# {{{ formatLuksDevice 
sub formatLuksDevice($$$$) {
    my($containerPath, $keyPath, $cipher, $keySize) = @_;

    if ( -e $containerPath ) {
        if ( -e $keyPath ) { 
            my @outPut = `sudo env cryptsetup luksFormat $containerPath -d $keyPath -c $cipher -s $keySize --batch-mode`;
            #print Dumper \@outPut;
            if (! $?) { return true; } else { return false; }  
        } else { 
            $log->error("keyPath not exist: $keyPath");
            return false;
          }
    } else { 
        $log->error("containerPath not exist: $containerPath");
        return false;
      }
}
# }}}

# {{{ cryptsetupInfo 
sub cryptsetupInfo(;$) {
    my($Name) = @_;
    my(%ret, %mpdc, $lllv);

    if ( ! defined $Name ) {
        $lllv = dmsetupInfo();
    } else { 
        my %tmp = ( $Name => undef, );
        $lllv = \%tmp;
    }
    foreach my $key (keys %$lllv) {
        my @outPut = `sudo cryptsetup status $key`;
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

# {{{ createFsDevice
sub createFsDevice($$) {
    my($fsName,$pathDevice) = @_;
    my $fsComm;
    my %fsHash = (                 # ADD new FS with params
        "reiserfs" => "sudo mkreiserfs -q",
        "ext4"     => "sudo mkfs.ext4"
    );

    if ( -e $pathDevice ) {
        $fsComm = $fsHash{$fsName};
        if ( defined $fsComm) { 
            my @outPut = `env $fsComm $pathDevice`;
            if (! $?) { return true; } else { return false; }  
        } else { 
            $log->error("fs not exist: $fsComm");
            return false;
        }
    } else { 
        $log->error("device not exist: $pathDevice");
        return false;
    }
}
# }}}

# {{{ mountFsDevice     #need revision
sub mountFsDevice($$;$) {
    my($pathDevice, $mountPoint, $userName) = @_;
    my @outPut;

    if ( -e $pathDevice ) {
        if ( -d $mountPoint ) {
             @outPut = `sudo env mount $pathDevice $mountPoint`;
            if ( $? == 0 and defined $userName) {
                @outPut = `sudo chown -hR $userName:$userName $mountPoint`;
                #for inverting bash exit to perl exit status 
                if (! $?) { return true; } else { return false; }  
                #return $?;
            }
            if (! $?) { return true; } else { return false; }
            #return $?;
        } else { 
            $log->error("mount point not exist: $mountPoint");
            return false;
        }
    } else { 
        $log->error("device not exist: $pathDevice");
        return false;
    }
}
# }}}

# {{{ findMountDevice   #need revision
sub findMountDevice($) { 
    my($containerName) = @_;
    my $containerInfo =  dmsetupInfo($containerName); 
    my $mountStruct = getMountStruct();
    foreach my $val (@$mountStruct) {
        if ( $val->{'part'} =~ /$containerInfo->{$containerName}{'mapperPath'}/) {
            return $val;
        }
    }
    return false;
}
# }}}

# {{{ getMountStruct
sub getMountStruct() {
    open (my $fd, '<', '/proc/mounts') or die "Could not open file '/proc/mount' $!";
    my(@ret);
    while (<$fd>)  {
        my @spl = split(/ /, $_);
        foreach my $val (@spl) { chomp $val; }
        my %mountStruct;
        $mountStruct{'part'} = $spl[0];
        $mountStruct{'point'}   = $spl[1];
        $mountStruct{'fs'}   = $spl[2];
        my @spl2 = split(/,/,$spl[3]); 
        $mountStruct{'options'}   = \@spl2;
        $mountStruct{'dump'} = $spl[4];
        $mountStruct{'fsck'} = $spl[5];
        push @ret, \%mountStruct; 
        }
    return \@ret;
}
# }}}

# {{{ umountFsDevice 
sub umountFsDevice($) {
    #path device or mount point
    my($pathDoMp) = @_;
    my @outPut = `sudo env umount $pathDoMp`;
    if (! $?) { return true; } else { return false; }  
    }
# }}}

#{{{ closeLuksDevice 
sub closeLuksDevice($) { 
    my($containerName) = @_;
    my $mountDeviceStruct = findMountDevice($containerName);
    if ($mountDeviceStruct) {
        if ( ! umountFsDevice($mountDeviceStruct->{'point'})) {
            $log->error("can not umount device: $mountDeviceStruct->{'part'} mount point: $mountDeviceStruct->{'point'}");
            return false;
        }
    }
    my @outPut = `sudo env cryptsetup close $containerName`;
    if (! $?) { return true; } else { return false; }  
}
# }}}

# {{{ openLuksDevice 
sub openLuksDevice($$$) {
    my($containerName, $containerPath, $keyPath) = @_;

    if ( -e $containerPath ) {
        if ( -e $keyPath ) { 
            #my($containerName, $directories, $suffix) = fileparse($containerPath);
            my @outPut = `sudo cryptsetup luksOpen $containerPath -d $keyPath  $containerName`;
            if (! $?) { return true; } else { return false; }  
        } else { 
            $log->error("keyPath not exist: $keyPath");
            return false;
        }
    } else { 
        $log->error("containerPath not exist: $containerPath");
        return false;
    }
}
# }}}

true;
