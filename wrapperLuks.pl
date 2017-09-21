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

if (closeLuksDevice($containerName)) {
    $log->info("close Luks Device: OK -> $containerName");
}
exit(1);

my($keyFolder, $containerPrivateFolder, $mountPrivateFolder) =  createStructDirV2();
#требуется проверка на существование контейнера
my($containerPath) = createFileContainer($containerPrivateFolder, $containerName, $containerSize);

my($keyPath) = createKeyFile($keyFolder, $containerName, $keySize);

if (formatLuksDevice($containerPath, $keyPath, $cipher, $keySize)) {
    $log->info("luksFormatStatus: OK");
}

if (openLuksDevice($containerName, $containerPath, $keyPath)) {
    $log->info("openLuksDeviceStatus: OK");
}

my $cryptNodeInfo = cryptsetupInfo($containerName);
#print Dumper $cryptNodeInfo;
#print $cryptNodeInfo->{"$containerName"}{"mapperPath"};

if (createFsDevice("reiserfs", $cryptNodeInfo->{$containerName}{"mapperPath"})) {
    $log->info("createFsDeviceStatus: OK");
}

my $mountPoint = $mountPrivateFolder . "/" . $containerName;
if ( ! -d $mountPoint ) { 
    make_path($mountPoint, {verbose => 0, mode => 0700});
    $log->info("create mount point: $mountPoint");
}

if (mountFsDevice($cryptNodeInfo->{$containerName}{"mapperPath"}, $mountPoint, $user)) {
    $log->info("mountFSstatus: OK");
}
