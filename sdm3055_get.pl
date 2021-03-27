#!/usr/bin/perl
#===============================================================================
#
#         FILE: siglent3055_get.pl
#
#        USAGE: ./sdm3055_get.pl  options
#
#  DESCRIPTION: read measurements from SIGLENT SDM 3055 multimeter
#
#      OPTIONS: ---
# REQUIREMENTS: --- Lab::VXI11, Getopt::Long, Time::HiRes
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: Anton Guda (atu)
#      VERSION: 0.1
#      CREATED: 03/06/21 15:07:50
#      LICENSE: GPLv3
#===============================================================================

use strict;
use warnings;
use utf8;

use Getopt::Long qw(:config no_ignore_case ); # auto_help
use Time::HiRes qw( usleep gettimeofday );
# use Time::HiRes::Sleep::Until;
use Lab::VXI11;

STDOUT->autoflush( 1 );

my $debug     = 0; # 1 while test
my $addr      = '192.168.0.222';
my $measure   = 'VOLT:DC';
my $range     = 'AUTO';
my $timeout   = 3000;
my $samples   = 1;
my $t_read    = 0.0;
my $n_read    = 1;
my $timestamp = 0;
my $extra_cfg = '';

my %opts = (
    'd|debug+'       => \$debug,
    'a|addr=s'       => \$addr,
    'm|measure=s'    => \$measure,
    's|samples=o'    => \$samples,
    'r|range=s'      => \$range,
    't|t_read=f'     => \$t_read,
    'n|n_read=o'     => \$n_read,
    'T|timeout=i'    => \$timeout,
    'p|timestamp!'   => \$timestamp,
    'x|extra_cfg=s'  => \$extra_cfg,
);

my %measure_name = (
    'V'    => 'VOLT:DC ',
    'VDC'  => 'VOLT:DC ',
    'VAC'  => 'VOLT:AC ',
    'VA'   => 'VOLT:AC ',
    'R'    => 'RES ',
    'OHM'  => 'RES ',
    'R4'   => 'FRES ',
    'OHM4' => 'FRES ',
    'I'    => 'CURR:DC ',
    'IDC'  => 'CURR:DC ',
    'IAC'  => 'CURR:AC ',
    'IA'   => 'CURR:AC ',
    'F'    => 'FREQ ',
    'HZ'   => 'FREQ ',
    'T'    => 'PER ',
    'PER'  => 'PER ',
);

my $opt_rc = GetOptions ( %opts );

if( !$opt_rc ) {
  print( STDERR "Usage: sdm3055_get.pl [options]\n Options:\n\n");
  while( my ($key,$val) = each( %opts )  ) {
    print( STDERR " -" . $key . "\n" );
  }
  print( STDERR "Measure: " );
  while( my ($key,$val) = each( %measure_name )  ) {
    print( STDERR $key . ", " );
  }
  print( STDERR "\n" );
  exit(0);
};

if( $debug > 0 ) {
  while( my ($key,$val) = each( %opts )  ) {
    print( STDERR "# $key = " . $$val . "\n" );
  }
}


my $client = Lab::VXI11->new( $addr, DEVICE_CORE, DEVICE_CORE_VERSION, 'tcp' );

if( ! defined $client ) {
  die "cannot create client.";
}

my ( $error, $lid, $abortPort, $maxRecvSize ) = $client->create_link( 0, 0, 0, 'inst0' );
if( $error != 0 ) {
  die "Fail to create link, error= $error";
}

my( $reason, $data, $size );

$samples = int($samples);

my $cfg = "SAMP:COUNT $samples;\n";

my $me_u = uc( $measure );

if( defined $measure_name{$me_u} ) {
    $measure = $measure_name{$me_u};
}


$cfg .= 'CONF:' . $measure;

if( $range ne 'AUTO' ) {
  $cfg .= $range;
}
$cfg .= ";\n";

if( $debug > 0 ) {
  print( STDERR "# cfg=\"" . $cfg . "\" me_u = \"" . $me_u . "\"\n" );
}
if( $extra_cfg ) {
  $cfg .= $extra_cfg . ';\n';
}

( $error, $size )          = $client->device_write( $lid, $timeout, 0, 0x08, $cfg );
if( $error != 0 ) {
  die( "Fail to write cfg. error= $error, cfg=\"" . $cfg . "\"" );
}

my $cmd = "INIT;FETCH?";
my $val = 0.0;

my $t0;
my $tc;

for( my $i=0; $i<$n_read; ++$i ) {

  my $t_00 = gettimeofday();
  ( $error, $size ) = $client->device_write( $lid, $timeout, 0, 0x08, $cmd );
  if( $error != 0 ) {
    die( "Fail to write cmd. error= $error, cfg=\"" . $cmd . "\"" );
  }

  ( $error, $reason, $data ) = $client->device_read( $lid, 1024, $timeout, 0, 0, 0 );
  if( $error != 0 ) {
    die( "Fail to read. error= $error, cfg=\"" . $cmd . "\"" );
  }

  $tc = gettimeofday();
  if( $i == 0 ) {
    $t0 = $tc;
  }

  chomp $data;
  if( $debug > 1 ) {
    print( STDERR "# " . ( $tc - $t_00 ) . ' ' . $data . "\n" );
  }

  if( $timestamp ) {
    printf( "%-07.03g ", $tc-$t0 );
  }
  my @datas = split( ',', $data );
  foreach my $cdat ( @datas ) {
    $val = ( 0.0 + $cdat );
    printf( "%-14.8g \n", $val );
    if( $debug > 1 ) {
      print( STDERR "# " . $cdat , "\n" );
    }
  }

  if( $t_read > 0 ) { # TODO: sleep_until
    usleep( $t_read * 1000000 );
  }
}


$client->device_write( $lid, $timeout, 0, 0x08, "ABORT;*CLS" );
$client->destroy_link( $lid );

