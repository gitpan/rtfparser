#!/usr/local/bin/perl
# Sonovision-Itep, Verdret 1995-1998
# Many helpful comments from:
# - Bruce gingery [bgingery@gtcs.com]

# You can try this converter on replicas.rtf
# from <http://www.research.microsoft.com/~gray/replicas.rtf>

require 5.000;
use strict;

my $VERSION = "0.8";

#BEGIN {  unshift @INC, "." }
use Getopt::Long;
use File::Basename;

($::basename, $::dirname) = fileparse($0); 
my $usage = "usage: $::basename [-l log file] RTF file(s)";
my $help = "";

use vars qw($EOM $trace $opt_d $opt_h $opt_t $opt_v);
use RTF::Config;

$EOM = "\n";			# end of message
$trace = 0;
GetOptions('h',			# Help
	   't=s',		# name of the target document
	   'r=s',		# name of the report file
	   'd',			# debugging mode
	   'v',			# verbose
	   'l=s' => \$LOG_FILE,	# -l logfile
	  ) or die "$usage";

# Option management
if ($opt_h) {
  print STDOUT "$help\n";
  exit 0;
}
if ($opt_d) {
  $| = 1;
  $EOM = "";
}
if ($LOG_FILE ne '') {
  print "$LOG_FILE\n";
  print STDERR qq^See Informations in the "$LOG_FILE" file\n^;
#  open (LOG, "> $LOG_FILE") or
#    die "can't open file: $LOG_FILE ($!)";
} else {
#  open (LOG, "/dev/null");
}

select(STDOUT);

require RTF::HTML::Output;
my $filename;
my $self = new RTF::HTML::Output;	

foreach my $filename (@ARGV) {
  $self->parseFile($filename);
}

1;
