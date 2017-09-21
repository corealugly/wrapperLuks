#!/usr/bin/env perl 
use strict;
use warnings;
use utf8;
use Cwd 'abs_path';
require 'func.pl';
use boolean;
use Data::Dumper;
use Log::Any qw($log);
use Log::Any::Adapter ('Stdout');

my $view = true;
#my $containerName = "def." . time();
my $containerName = "testV1";
my $containerSize = "50";
my $cipher = "aes-xts-plain64";
my $keySize = "512";


my $user = getpwuid( $< );
print "\$user = $user\n";

my $sudo_user = $ENV{'SUDO_USER'}; 
print "\$SUDO_USER = $sudo_user\n";

my $absPath = abs_path($0);
print "ABS path: $absPath\n";

#my $uid   = $<;
#print "\$uid = $uid\n";

#dmsetupInfo();
#cryptsetupInfo();
#-------------
my($keyFolder, $containerPrivateFolder, $mountPrivateFolder) =  createStructDirV2();

#print $keyFolder . "\n";
#print $containerPrivateFolder . "\n";
#print $mountPrivateFolder . "\n";
#------------

my($containerPath) = createFileContainer($containerPrivateFolder, $containerName, $containerSize);
print "containerPath: " . $containerPath . "\n";

#------------

my($keyPath) = createKeyFile($keyFolder, $containerName, $keySize);
print "keyPath: " . $keyPath . "\n";

#------------

my($luksFormatStatus) = formatLuksDevice($containerPath, $keyPath, $cipher, $keySize);
if ($luksFormatStatus == 0) {
    print "luksFormatStatus: " . "OK" . "\n";
}

#------------

my($openLuksDeviceStatus) = openLuksDevice($containerName, $containerPath, $keyPath);
print "openLuksDeviceStatus: " . "$openLuksDeviceStatus" . "\n";

#------------

my $cryptNodeInfo = cryptsetupInfo($containerName);
print Dumper $cryptNodeInfo;
print $cryptNodeInfo->{"$containerName"}{"mapperPath"};
#------------

my($createFsDeviceStatus) = createFsDevice("reiserfs", $cryptNodeInfo->{$containerName}{"mapperPath"});
if ($createFsDeviceStatus == 0) {
    $log->info("createFsDeviceStatus: " . "OK");
}

my $mountPoint = $mountPrivateFolder . "/" . $containerName;
if ( ! -d $mountPoint ) { 
    my @created = make_path($mountPoint, {verbose => 1, mode => 0700});
    $log->info("create folder keys: $mountPoint");
} 
my($mountFSstatus) = mountFsDevice($cryptNodeInfo->{$containerName}{"mapperPath"}, $mountPoint);
if ($mountFSstatus == 0) {
    $log->info("mountFSstatus: OK");
}
