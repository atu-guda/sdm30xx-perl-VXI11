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
# REQUIREMENTS: --- Lab::VXI11, Getopt::Long, Time::HiRes, Device::SDM3055 (local)
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

use Device::SDM3055;

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


my $opt_rc = GetOptions ( %opts );

if( !$opt_rc ) {
  print( STDERR "Usage: sdm3055_get.pl [options]\n Options:\n\n");
  while( my ($key,$val) = each( %opts )  ) {
    print( STDERR " -" . $key . "\n" );
  }
  print( STDERR "Measure: " . Device::SDM3055::getMeasureNamesStr() . "\n" );
  exit(0);
};

if( $debug > 0 ) {
  while( my ($key,$val) = each( %opts )  ) {
    print( STDERR "# $key = " . $$val . "\n" );
  }
}

my $mult1 = Device::SDM3055->new( $addr );
$mult1->{debug} = $debug;


$mult1->setMeasure( $measure, $range );
$mult1->setSamples( $samples );

if( $extra_cfg ) {
  $mult1->sendCmd( $extra_cfg );
}


my $t_0;

for( my $i=0; $i<$n_read; ++$i ) {

  my $t_sti = gettimeofday();
  my @datas = $mult1->getNextDatas();
  if( !@datas ) {
    die( "Fail to get Next data  error= " . $mult1->getError()  ); # or not die?
  }

  my $t_c = gettimeofday();
  if( $i == 0 ) {
    $t_0 = $t_c;
  }

  if( $debug > 0 ) {
    print( STDERR "# " . ( $t_c - $t_sti ) . ' ' . ( $t_c - $t_0 ) . ' ' . $mult1->getData() . "\n" );
  }

  if( $timestamp ) {
    printf( "%-09.3f ", $t_c - $t_0 );
  }

  foreach my $val ( @datas ) {
    printf( "%-14.8g ", $val );
  }
  print( "\n" );


  if( $t_read > 0.01 ) {
    my $t_next = $t_0 + ($i+1) * $t_read;
    my $t_dlt =  1000000 * ( $t_next - $t_c ) - 23000; # approx time for "slow" measurement
    if( $t_dlt > 0 ) {
      usleep( $t_dlt );
    }
  }
}



