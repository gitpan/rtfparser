# Sonovision-Itep, Philippe Verdret 1998
# RTF Reader

require 5.004;
use strict;

package RTF::Parser;
use RTF::Config;
use File::Basename;

use vars qw($line);
use Carp;
if (PARSER_TRACE) {
  $SIG{__DIE__} =  $SIG{'INT'} = sub { 
    confess;			# print the stack trace
  };
}

# RTF Specification
# The delimiter marks the end of the RTF control word, and can
# be one of the following:
# 1. a space. In this case, the space is part of the control word
# 2. a digit or an hyphen, ...
# 3. any character other than a letter or a digit
# 
my $CONTROL_WORD = '[a-z]{1,32}'; # '[a-z]+';
my $CONTROL_ARG = '-?\d+';	# argument of control words, or: (?:-[0-9]+|[0-9]+)
my $END_OF_CONTROL = '(?:[ ]|(?=[^a-z0-9]))'; 
my $CONTROL_SYMBOLS = q![-_~:|{}*\'\\\\]!; # Symbols (Special characters)
my $DESTINATION = '[*]';	# 
my $DESTINATION_CONTENT = '(?:[^\\\\{}]+|\\\\.)+'; 
my $HEXA = q![0-9abcdef][0-9abcdef]!;
my $PLAINTEXT = '[^{}\\\\]+(?:\\\\\\\\[^{}\\\\]*)*'; 
my $BITMAP_START = '\\\\{bm(?:[clr]|cwd) '; # Ex.: \{bmcwd 
my $BITMAP_END = q!\\\\}!;
my $BITMAP_FILE = '(?:[^\\\\{}]+|\\\\[^{}])+'; 

my $EOR = "\n";
if ($OS eq 'UNIX') {
  $EOR = q!\r?\n!;		# todo: autodeterrmination
} else {
  $EOR = q!\n!;			# binmode() will do the job
}
			
# reference of the hash which contains the processed control words 
# used by the "destination" processing

# interface must change if you want to write: $self->$1($1, $2);
# $self->$control($control, $arg, 'start');

my $DO_ON_CONTROL = \%RTF::Control::do_on_control; # default
sub controlDefinition {
  my $self = shift;
  if (@_) {
    if (ref $_[0]) {
      $DO_ON_CONTROL = shift;
    } else {
      die "argument of controlDefinition method must be a hash reference";
    }
  } else {
    $DO_ON_CONTROL;
  }
}

# Generate in the control class???
{ package Action;		
  use vars qw($AUTOLOAD);
				# should be optional
  my $default = sub { $RTF::Control::not_processed{$_[1]}++ };
  sub AUTOLOAD {
    my $self = $_[0];
    $AUTOLOAD =~ s/^.*:://;	
    no strict 'refs';
    if (defined (my $sub = ${$DO_ON_CONTROL}{"$AUTOLOAD"})) {
      # Generate on the fly a new method, and call it
      #*{"$AUTOLOAD"} = $sub; &{"$AUTOLOAD"}(@_); 
      # OOP: *{"$AUTOLOAD"} = $sub; $self->$AUTOLOAD(@_);
      # &{*{"$AUTOLOAD"} = $sub}(@_); 
      goto &{*{"$AUTOLOAD"} = $sub}; 
    } else {
      *{"$AUTOLOAD"} = $default;	
    }
  }
}
sub DESTROY {}
			# Class API
sub parseStart {}
sub parseEnd {}
sub groupStart {}
sub groupEnd {}
sub text {}
sub char {}
sub symbol {}
sub destination {}
sub bitmap {}
sub binary {}			# not call
sub error {			# not used
  my($self, $message) = @_;
  my $atline = $.;
  my $infile = $self->{filename};
}

sub new {
  my $receiver = shift;
  my $class = (ref $receiver or $receiver);
  my $self = bless {
		    'buffer' => '', # internal buffer
		    'eof' => 0,	# 1 if EOF, not used
		    'filename' => '', # filename
		    'filehandle' => '',	# filehandle to read
		    'line' => 0, # not used
		    'EOR' => $EOR, # not used
		   }, $class;
  $self;
}

sub line { $_[1] ? $_[0]->{line} = $_[1] : $_[0]->{line} } 
sub filename { $_[1] ? $_[0]->{filename} = $_[1] : $_[0]->{filename} } 
sub buffer { $_[1] ? $_[0]->{buffer} = $_[1] : $_[0]->{buffer} } 
sub eof { $_[1] ? $_[0]->{eof} = $_[1] : $_[0]->{eof} } 

sub parseFile {
  my $self = shift;
	
  my $file = shift;
  unless (defined $file) {
    die "file not defined";
  }
  no strict 'refs';		# so that a symbol ref as $file works
  local(*F);
  unless (ref($file) or $file =~ /^\*[\w:]+$/) {
    $self->{filename} = $file;
    # Assume $file is a filename
    open(F, $file) or die "Can't open '$file' ($!)";
  } else {
    *F = $file;
  }
  binmode(F) unless $OS eq 'UNIX'; # or something like this
  my $filehandle = $self->{filehandle} = \*F;
  $self->{'eof'} = 0;
  my $buffer = '';
  $self->{'buffer'} = \$buffer;

  $self->parseStart();		# Action before parsing
  $self->read()
    or die "unexpected end of data in '$file'";

  my $loop = 0;
  while (1) {
    $buffer =~ s/^\\($CONTROL_WORD)($CONTROL_ARG)?$END_OF_CONTROL//o and do {
      my ($control, $arg) = ($1, $2);
      &{"Action::$control"}($self, $control, $arg, 'start');
      next;
    };
    $buffer =~ s/^\{\\$DESTINATION\\($CONTROL_WORD)($CONTROL_ARG)?$END_OF_CONTROL//o and do { 
      # RTF Specification: "discard all text up to and including the closing brace"
      # Example:  {\*\controlWord ... }
      # '*' is an escaping mechanism


      if (defined ${$DO_ON_CONTROL}{$1}) { # if it's a registered control then don't skip
	$buffer = "\{\\$1$2" . $buffer;
      } else {			# skip!
	my $level = 1;
	my $content = "\{\\*\\$1$2";
	$self->{'start'} = $.;		# could be used in the error method
	while (1) {
	  $buffer =~ s/^($DESTINATION_CONTENT)//o and do {
	    $content .= $1;
	    next
	  };
	  $buffer =~ s/^\{// and do {
	    $content .= "\{";
	    $level++;
	    next;
	  };
	  $buffer =~ s/^\}// and do { # 
	    $content .= "\}";
	    --$level == 0 and last;
	    next;
	  };
	  if ($buffer eq '') {
	    $self->read() 
	      or 
		die "unexpected end of file: unable to find end of destination"; 
	    next;
	  } else {
	    die "unable to analyze '$buffer' in destination"; 
	  }
	}
	$self->destination($content);
      }
      next;
    };
    $buffer =~ s/^\{(?!\\[*])// and do { # can't be a destination
      $self->groupStart();
      next;
    };

    $buffer =~ s/^\}// and do {		# 
      $self->groupEnd();
      next;
    };
    $buffer =~ s/^($PLAINTEXT)//o and do {
      $self->text($1);
      next;
    };
    $buffer =~ s/^\\\'($HEXA)//o and do {
      $self->char($1);	
      next;
    };
    $buffer =~ s/^$BITMAP_START//o and do { # bitmap filename
      my $filename;
      do {
	$buffer =~ s/^($BITMAP_FILE)//o;
	$filename .= $1;
	
	if ($buffer eq '') {
	  $self->read() 
	    or 
	      die "unexpected end of file"; 
	}

      } until ($buffer =~ s/^$BITMAP_END//o);
      $self->bitmap($filename);
      next;
    };
    $buffer =~ s/^\\($CONTROL_SYMBOLS)//o and do {
      $self->symbol($1);
      next;
    };
    $self->read() and next;
    # can't goes there if everything is alright, except one time on eof
    last if $loop++ > 0;	
  }
				# should be in parseEnd()
  if ($buffer ne '') {  
    my $data = substr($buffer, 0, 100);
    die "unanalized data: '$data ...' at line $. file $self->{filename}\n";  
  }

  $self->parseEnd();		# Action after
  close(F);
  $self;
}

sub skipbin {			# skip binary data, not tested
  my $self = shift;
  my $length = shift;
  my $buffer = ${$self->{'buffer'}};
  $self->{'buffer'} = \$buffer;
  while ($length > 0) {
    if (($length -= length($buffer)) >= 0) {
      $buffer = '';
      $self->read(); #or die "unexpected end of file"; 
      print STDERR "=>$buffer\n";
    } else {
      $length = 0;
      substr($buffer, 0, $length) = '';
    }
  }
}

# what is the most efficient reader?
# You can also use: if (chomp(${$_[0]->{'buffer'}} .= <$FH>)) {
sub read {			# by line
  my $FH = $_[0]->{'filehandle'};
  if ((${$_[0]->{'buffer'}} .= <$FH>) =~ s!$EOR$!!o) {
    1;
  } else {
    $_[0]->{eof} = 1;
    0;
  }
}
1;
__END__

