# Sonovision-Itep, Verdret 1998
# 
# Stack machine - should be ideally application independant!
# 
# define some interesting events for your application

use strict;
package RTF::Control;
use RTF::Parser;
use RTF::Config;
use RTF::Charsets;

use Exporter;
@RTF::Control::ISA = qw(Exporter RTF::Parser);

				# here is what you can use in your application

use vars qw(%char %symbol %info %do_on_event %par 
	    $style $newstyle $event $text);
@RTF::Control::EXPORT = qw(output 
			   %char %symbol %info %do_on_event %par 
			   $style $newstyle $event $text);

%do_on_event = ();		# output routines
$style = '';			# current style
$newstyle = '';			# new style if style changing
$event = '';			# start or end
$text = '';			# pending text
%symbol = ();			# symbol translations
%char = ();			# character translations
%par = ();			# some paragraph decorations
%info = ();			# info part of the document

###########################################################################
				# Interface specification of callbacks methods
				# so you can easily reorder arguments
use constant SELF => 0;
use constant CONTROL => 1;
use constant ARG => 2;
use constant EVENT => 3;

###########################################################################
				# Automata states, control modes
my $IN_STYLESHEET = 0;	# in or out of style table
my $IN_FONTTBL = 0;		# in or out of font table
my $IN_TABLE = 0;

my %fonttbl;
my %stylesheet;
my %parStack;
				#
my @par = ();			# stack of paragraph properties
my @control = ();		# stack of control instructions
my $stylename = '';
my $cstylename = '';		# previous encountered style
my $clineindent = 0;
my $styledef = '';

###########################################################################
				# output stack management
my @output_stack;
use constant MAX_OUTPUT_STACK_SIZE => 0; # 8 seems a good value
my $nul_output_sub = sub {};
my $string_output_sub = sub { $output_stack[-1] .= $_[0]; };
sub output { 
  $output_stack[-1] .= $_[0] 
};
sub push_output {  
  if (MAX_OUTPUT_STACK_SIZE) {
    die "max size of the output stack exceeded" if @output_stack == MAX_OUTPUT_STACK_SIZE;
  }
  if ($_[0] eq 'nul') {
    *output = $nul_output_sub;
  } else {
    *output = $string_output_sub; 
  }
  push @output_stack, '';
}
sub pop_output {  pop @output_stack; }

###########################################################################
				# Trace management
my $max_depth = 0;
use vars qw(%not_processed);
use constant TRACE => 1;	# General trace
$| = 1;
use constant STACK_TRACE => 0; # 

# is it possible to find the associated control instruction?
#caller() returns:
#RTF::Parser RTF/Parser.pm 150 RTF::Control::__ANON__ 1 
sub trace {
  my(@caller) = (caller(1));
  my $sub = (@caller)[3];
  $sub =~ s/.*:://;
  $sub = sprintf "%-12s", $sub;
  #print STDERR ('_' x $#control . "[$sub] @_\n");
  #output ('_' x $#control . "@_\n");
  print STDERR ('_' x $#control . "@_\n");
}
$SIG{__DIE__} = sub {
  require Carp;
  Carp::confess;
};
###########################################################################
				# default mapping for symbols
%symbol = qw(
	     | |
	     _ _
	     : :
	     rdblquote "
	     ldblquote "
	     endash -
	     emdash -
	     bullet o
	     rquote '
	    );			# '


				# Some generic routines
sub do_on_symbol { output $symbol{$_[CONTROL]} }

				# Many situations can occur:
				# {\<toggle> ...}
				# {\<toggle>0 ...}
				# \<control>\<toggle>
				# eg: \par \pard\plain \s19 \i\f4

use constant DO_ON_TOGGLE => 0;
sub do_on_toggle {
  return if $IN_STYLESHEET or $IN_FONTTBL;
  my($control, $arg, $cevent) = ($_[CONTROL], $_[ARG], $_[EVENT]);
  trace "my($control, $arg, $cevent) = ($_[CONTROL], $_[ARG], $_[EVENT]);" if DO_ON_TOGGLE;

  if ($_[ARG] eq "0") { 
    $cevent = 'end';
    trace "argument: |$_[ARG]| at line $.\n" if DO_ON_TOGGLE;
    $control[-1]->{"$_[CONTROL]1"} ; # register an END event
    if (defined (my $action = $do_on_event{$control})) {
      ($style, $event, $text) = ($control, 'end', '');
      &$action;
    } 
  } elsif ($_[EVENT] eq 'start') {
    $control[-1]->{"$_[CONTROL]$_[ARG]"} = 1;
    
    if (defined (my $action = $do_on_event{$control})) {
      ($style, $event, $text) = ($control, 'start', '');
      trace "($style, $event, $text)\n" if DO_ON_TOGGLE;
      &$action;
    } 
    
  } else {			# END
    $cevent = 'start' if $_[ARG] eq "1"; # see above
    if (defined (my $action = $do_on_event{$control})) {
      ($style, $event, $text) = ($control, $cevent, '');
      &$action;
    } 
  }
}
use constant DISCARD_CONTENT => 0;
sub discard_content {		
  my($control, $arg, $cevent) = ($_[CONTROL], $_[ARG], $_[EVENT]);
  trace "($_[CONTROL], $_[ARG], $_[EVENT])" if DISCARD_CONTENT;
  if ($_[ARG] eq "0") { 
    pop_output();
    $control[-1]->{"$_[CONTROL]1"} = 1;
  } elsif ($_[EVENT] eq 'start') { 
    push_output();
    $control[-1]->{"$_[CONTROL]$_[ARG]"} = 1;
  } elsif ($_[ARG] eq "1") { # see above
    $cevent = 'start';
    push_output();
  } elsif ($_[EVENT] eq 'end') { # End of discard
    my $string = pop_output();
    if (length $string > 30) {
      $string =~ s/(.{1,10}).*(.{1,10})/$1 ... $2/;
    }
    trace "discard content of \\$control: $string" if DISCARD_CONTENT;
  } else {
    die "($_[CONTROL], $_[ARG], $_[EVENT])" if DISCARD_CONTENT;
  }
}


my %charset;
my $bulletItem;
sub define_charset {
  #my($control, $arg, $cevent) = ($_[CONTROL], $_[ARG], $_[EVENT]);
  no strict qw/refs/;
  %charset = %{"$_[CONTROL]"};
  $bulletItem = quotemeta($char{'periodcentered'});
}
use constant DO_ON_FLAG => 0;
sub do_on_flag {
  #my($control, $arg, $cevent) = ($_[CONTROL], $_[ARG], $_[EVENT]);
  die if $_[ARG];			# no argument by definition
  trace "$_[CONTROL]" if DO_ON_FLAG;
}
sub do_on_info {		# 'info' content
  #my($control, $arg, $cevent) = ($_[CONTROL], $_[ARG], $_[EVENT]);
  my $string;
  if ($_[EVENT] eq 'start') { 
    push_output();
    $control[-1]->{"$_[CONTROL]$_[ARG]"} = 1;
  } else {
    $string = pop_output();
    $info{"$_[CONTROL]$_[ARG]"} = $string;
  }
}
				# Association between controls and actions
my %toggle = ();
use vars qw(%do_on_control);
%toggle =			# Just an example, do the same thing 
  (				# for all RTF toggles : 'i', 'ul'
   'b' => \&do_on_toggle,
   'i' => \&do_on_toggle,
   'ul' => \&do_on_toggle,
   'sub' => \&do_on_toggle,
   'super' => \&do_on_toggle,
  );
%do_on_control = 
  (
   '__undefined__', sub { $not_processed{$_[CONTROL]}++ },
   %toggle,
   'plain' => sub {
     unless (@control) {
       die "\@control stack is empty";
     }
     my @keys = keys %{$control[-1]};
     foreach my $control (@keys) {
       if (defined (my $action = $do_on_event{$control})) {
	 ($style, $event, $text) = ($control, 'end', '');
	 &$action;
       } 
     }
   },
   'rtf' => \&discard_content,	# 

				# Flags
   'ansi' => \&define_charset,	# The default
   'mac' => \&define_charset,	# Apple Macintosh
   'pc' => \&define_charset,	# IBM PC code page 437 
   'pca' => \&define_charset,	# IBM PC code page 850

   #'lang' => \&discard_content,	# only if {\lang1024 ...}
   'pict' => \&discard_content,	#
   'xe'  => \&discard_content,	# index entry
   #'v'  => \&discard_content,	# hidden text
   'bin' => sub { $_[SELF]->skipbin($_[ARG]) }, 

				# Color tables
   'colortbl' => \&discard_content,
   'info' => sub {		# {\info {...}}
     if ($_[EVENT] eq 'start') { 
       %info = ();
       push_output('nul');
       $control[-1]->{"$_[CONTROL]$_[ARG]"} = 1;
     } else {
       pop_output();
     }
   },
   # Other informations:
   # {\printim\yr1997\mo11\dy3\hr11\min5}
   # {\version3}{\edmins1}{\nofpages3}{\nofwords1278}{\nofchars7287}
   # {\*\company SONOVISION-ITEP}{\vern57443}
   'title' => \&do_on_info,
   'author' => \&do_on_info,
   'creatim' => \&do_on_info,	# {\creatim\yr1996\mo9\dy18\hr9\min17}
   'revtim' => \&do_on_info,
   'yr' => sub { output "$_[ARG]-" },
   'mo' => sub { output "$_[ARG]-" },
   'dy' => sub { output "$_[ARG]-" },
   'hr' => sub { output "$_[ARG]-" },
   'min' => sub { output "$_[ARG]" },   
				# Font processing
   'fonttbl' => sub {
     #trace "fonttbl $#control $_[CONTROL] $_[ARG] $_[EVENT]";
     if ($_[EVENT] eq 'start') { 
       $IN_FONTTBL = 1 ;
       push_output('nul');
       $control[-1]->{"$_[CONTROL]$_[ARG]"} = 1;
     } else {
       $IN_FONTTBL = 0 ;
       pop_output();
     }
   },

   'f', sub {			
     #my($control, $arg, $cevent) = ($_[CONTROL], $_[ARG], $_[EVENT]);

     use constant FONTTBL_TRACE => 0; # if you want to see the fonttbl of the document
     if ($IN_FONTTBL) {
       if ($_[EVENT] eq 'start') {
	 push_output();
	 $control[-1]->{"$_[CONTROL]$_[ARG]"} = 1;
       } else {
	 my $fontname = pop_output;
	 my $fontdef = "$_[CONTROL]$_[ARG]";
	 if ($fontname =~ s/\s*;$//) {
	   trace "$fontdef => $fontname" if FONTTBL_TRACE;
	   $fonttbl{$fontdef} = $fontname;
	 } else {
	   warn "$fontname";
	 }
       }
       return;
     }

     return if $styledef;	# if you have already encountered an \sn
     $styledef = "$_[CONTROL]$_[ARG]";

     use constant STYLESHEET_TRACE => 0; # If you want to see the stylesheet of the document
     if ($IN_STYLESHEET) {	# eg. \f4 => Normal;
       if ($_[EVENT] eq 'start') {
	 #trace "start $_[CONTROL]$_[ARG]" if STYLESHEET;
	 push_output();
	 $control[-1]->{"$_[CONTROL]$_[ARG]"} = 1;
       } else {
	 my $stylename = pop_output;
	 #trace "end\n $_[CONTROL]" if STYLESHEET;
	 if ($stylename =~ s/\s*;$//) {
	   trace "$styledef =>$stylename<" if STYLESHEET_TRACE;
	   $stylesheet{$styledef} = $stylename;
	 } else {
	   warn "$stylename";
	 }
       }
       $styledef = '';
       return;
     }

     $stylename = $stylesheet{"$styledef"};
     return unless $stylename;

     if ($cstylename ne $stylename) { # notify a style changing
       if (defined (my $action = $do_on_event{'style_change'})) {
	 ($style, $newstyle) = ($cstylename, $stylename);
	 &$action;
       } 
     }

     $cstylename = $stylename;
   },
				# 
				# Style processing
				# 
   'stylesheet' => sub {
     #trace "stylesheet $#control $_[CONTROL] $_[ARG] $_[EVENT]";
     if ($_[EVENT] eq 'start') { 
       $IN_STYLESHEET = 1 ;
       push_output('nul');
       $control[-1]->{"$_[CONTROL]$_[ARG]"} = 1;
     } else {
       $IN_STYLESHEET = 0;
       pop_output;
     }
   },
   's', sub {
     my($control, $arg, $cevent) = ($_[CONTROL], $_[ARG], $_[EVENT]);
     $styledef = "$_[CONTROL]$_[ARG]";

     if ($IN_STYLESHEET) {
       if ($_[EVENT] eq 'start') {
	 push_output();
	 $control[-1]->{"$_[CONTROL]$_[ARG]"} = 1;
       } else {
	 my $stylename = pop_output;
	 warn "empty stylename" and return if $stylename eq '';
	 if ($stylename =~ s/\s*;$//) {
	   trace "$styledef => $stylename|" if STYLESHEET_TRACE;
	   $stylesheet{$styledef} = $stylename;
	   $styledef = '';
	 } else {
	   warn "can't analyze style name: '$stylename'";
	 }
       }
       return;
     }

     $stylename = $stylesheet{"$styledef"};

     if ($cstylename ne $stylename) {
       if (defined (my $action = $do_on_event{'style_change'})) {
	 ($style, $newstyle) = ($cstylename, $stylename);
	 &$action;
       } 
     }

     $cstylename = $stylename;
   },
				# a very minimal table processing
   'cell' => sub {		# end of cell
     use constant TABLE_TRACE => 0;

     $text = pop_output;
     if (defined (my $action = $do_on_event{'cell'})) {
       $event = 'end';
       trace "cell $event $text\n" if TABLE_TRACE;
       &$action;
     } 
 				# prepare next
     push_output();
     trace "\@output_stack in table: ", @output_stack+0 if STACK_TRACE;
   },
   'trowd' => sub {		# row start
     #print STDERR "=>Beginning of ROW\n";
     unless ($IN_TABLE) {
       $IN_TABLE = 1;
       push_output();
       push_output();
       push_output();
     }
   },
   'row' => sub {		# row end
     $text = pop_output;
     if (defined (my $action = $do_on_event{'cell'})) {
       $event = 'end';
       trace "row $event $text\n" if TABLE_TRACE;
       &$action;
     } 
     $text = pop_output;
     if (defined (my $action = $do_on_event{'row'})) {
       $event = 'end';
       trace "row $event $text\n" if TABLE_TRACE;
       &$action;
     } 
				# prepare next row-cell
     push_output();
     push_output();
   },
   'intbl' => sub {
     $par{'intbl'} = 1;
     unless ($IN_TABLE) {	# in not in a table
       $IN_TABLE = 1;
       push_output();
       push_output();
       push_output();
     }
   },
   'par' => sub {		# END OF PARAGRAPH
     use constant STYLE_TRACE => 0; # 
     #my($control, $arg, $cevent) = ($_[CONTROL], $_[ARG], $_[EVENT]);
     trace "($_[CONTROL], $_[ARG], $_[EVENT])" if STYLE_TRACE;
     my $level = 2;

     if ($IN_TABLE) {
       if (not $par{'intbl'}) { # End of Table
	 #print STDERR "=>End of Table\n";
	 $IN_TABLE = 0;
	 #$trowd = 0;
	 my $next_text = pop_output;

	 $text = pop_output;
	 if (defined (my $action = $do_on_event{'cell'})) { # end of cell
	   $event = 'end';
	   trace "cell $event $text\n" if TABLE_TRACE;
	   &$action;
	 } 
	 $text = pop_output;
	 if (defined (my $action = $do_on_event{'row'})) { # end of row
	   $event = 'end';
	   trace "row $event $text\n" if TABLE_TRACE;
	   &$action;
	 } 
	 $text = pop_output;
	 if (defined (my $action = $do_on_event{'table'})) { # end of table
	   $event = 'end';
	   trace "table $event $text\n" if TABLE_TRACE;
	   &$action;
	 } 
	 push_output();	# put in front of the current buffer
	 output($next_text);
       } else {
	 trace "\@output_stack in table: ", @output_stack+0 if STACK_TRACE;
	 #push_output();	
       }
     }
     # for a future version!
#      use constant LINE_INDENT_TRACE => 0;
#      my($prePar, $postPar);
#      if ($parStack{'lineindent'} > $clineindent) {
#        trace "line indent: $parStack{'lineindent'} > $clineindent" if LINE_INDENT_TRACE;
#        push_output();	
#        ($style, $event, $text) = ($cstylename, 'sup');
#        if (defined (my $action = $do_on_event{'lineindent'})) {
# 	 &$action;
#        } 
#        $prePar = pop_output;
#      } elsif ($parStack{'lineindent'} < $clineindent) {
#        trace "line indent: $parStack{'lineindent'} < $clineindent" if LINE_INDENT_TRACE;
#        push_output();	
#        ($style, $event, $text) = ($cstylename, 'inf');
#        if (defined (my $action = $do_on_event{'lineindent'})) {
# 	 &$action;
#        } 
#        $postPar = pop_output;
#      }		       
				# Paragraph Style
     if ($cstylename ne '') { # end of previous style
       $style = $cstylename;
     } else {
       $cstylename = $style = 'par'; # no better solution
     }
       
     if ($par{intbl}) {	
       $text = pop_output;
       push_output(); 
       if (defined (my $action = $do_on_event{$style})) {
	 $event = 'end';
	 trace "cell $event $text\n" if TABLE_TRACE;
	 &$action;
       } 
     } elsif ($style ne 'par' and defined (my $action = $do_on_event{$style})) {
       ($style, $event, $text) = ($cstylename, 'end', pop_output);
       &$action;
       
       if (@output_stack == $level) { 
	 trace "\@output_stack: ", @output_stack+0 if STACK_TRACE;
	 print pop_output;        
	 push_output();  
       }
       push_output(); 
       
     } elsif (defined (my $action = $do_on_event{'par'})) {
       ($style, $event, $text) = ('par', 'end', pop_output);
       &$action;
       
       if (@output_stack == $level) {
	 trace "\@output_stack: ", @output_stack+0 if STACK_TRACE;
	 print pop_output;  
	 push_output(); 
       }
       push_output(); 
       
     } else {
       trace "no definition for '$style' in %do_on_event\n" if STYLE_TRACE;
       
       if (@output_stack == $level) {
	 print pop_output;  
	 push_output(); 
       }
       push_output(); 
     }
     $clineindent = $parStack{'lineindent'};
     $styledef = '';
     $par{'bullet'} = $par{'number'} = $par{'tab'} = 0; # 
   },
				# Resets to default paragraph properties
				# Stop inheritence of paragraph properties
   'pard' => sub {		
     $parStack{'lineindent'} = $par{'lineindent'} = 0;
     $par{'intbl'} = 0;
     #$par{'tab'} = 0;
     $cstylename = '';		# ???
   },
				# paragraph characteristics
				# What is Type of list?
   'pntext' => sub {
     #my($control, $arg, $cevent) = ($_[CONTROL], $_[ARG], $_[EVENT]);
     #if ($_[ARG] == 0) { $cevent = 'end' }; # ???
     #trace "pntext: ($_[CONTROL], $_[ARG], $_[EVENT])";
     my $string;
     if ($_[EVENT] eq 'start') { 
       push_output();
       $control[-1]->{"$_[CONTROL]$_[ARG]"} = 1;
     } else {
       $string = pop_output();
       $par{"$_[CONTROL]$_[ARG]"} = $string;
       #trace qq!pntext: $par{"$_[CONTROL]$_[ARG]"} = $string!;

       if ($string =~ s/^$bulletItem//o) { # Heuristic rules
	 $par{'bullet'} = 1;
       } elsif ($string =~ s/(\d+)[.]//) { # e.g. <i>1.</i>
	 $par{'number'} = $1;
       } else {
	 # letter???
       }
     }
   },
   'emdash' => \&do_on_symbol,
   'rquote' => \&do_on_symbol,
   'ldblquote' => \&do_on_symbol,
   'rdblquote' => \&do_on_symbol,
   #'tab' => sub { $par{'tab'} = 1 }, # special char

   'li' => sub {		# line indent
     use constant LI_TRACE => 0;
     my $indent = $_[ARG];
     $indent =~ s/^-//;
     trace "line indent: $_[ARG] -> $indent" if LI_TRACE;
     $parStack{'lineindent'} = $par{'lineindent'} = $indent;
   },
  );
###########################################################################
				# 
				# Callback methods
				# 
use constant DESTINATION_TRACE => 0;
sub destination {
  #my $self = shift;
  return unless DESTINATION_TRACE;
  my $destination = shift; 
  $destination =~ s/({\\[*]...).*(...})/$1 ... $2/ or die "invalid destination";
  trace "skipped destination: $destination" if DESTINATION_TRACE;
}

use constant GROUP_START_TRACE => 0;
sub groupStart {
  my $self = shift;
  trace "" if GROUP_START_TRACE;
  push @par, { %parStack };
  push @control, {};		# hash of controls
}
use constant GROUP_END_TRACE => 0;
sub groupEnd {
  %parStack = %{pop @par};
  $cstylename = $parStack{'stylename'}; # what the current style is
  no strict qw/refs/;
  foreach my $control (keys %{pop @control}) { # End Event!
    $control =~ /([^\d]+)(\d+)?/;
    trace "($#control): $1-$2" if GROUP_END_TRACE;
    &{"Action::$1"}($_[0], $1, $2, 'end'); # sub associated to $1 is already defined
  }
}
use constant TEXT_TRACE => 0;
sub text { 
  trace "$_[1]" if TEXT_TRACE;
  output($_[1]);
}
sub char {			
  my $name;
  my $char;
  if (defined($char = $char{$name = $charset{$_[1]}}))  {
    output "$char";
  } else {
    output "$name";	     
  }
}
sub symbol {
  if (defined(my $sym = $symbol{$_[1]}))  {
    output "$sym";
  } else {
    output "$_[1]";		# as it
  }
}

sub parseStart {
  my $self = shift;
  push_output();
  push_output();
  if (defined (my $action = $do_on_event{'document'})) {
    $event = 'start';
    &$action;
  } 
}
sub parseEnd {
  my $self = shift;
  my $action = '';
  
  trace "parseEnd \@output_stack: ", @output_stack+0 if STACK_TRACE;

  if (defined ($action = $do_on_event{'document'})) {
    ($style, $event, $text) = ($cstylename, 'end', pop_output);
    &$action;
  } 
  print pop_output;
  if (@output_stack) {
    my $string = pop_output;
    warn "unused string: '$string'" if $string;
  }
}
###########################################################################
END {
  if (@control) {
    trace "Stack not empty: ", @control+0;
  }
  if ($LOG_FILE) {
    open LOG, "> $LOG_FILE"
      or die qq^$::basename: unable to output data to "$LOG_FILE"$::EOM^;
    print "Maximum stack depth: ", $max_depth + 1, "\n";
    open LOG, "$LOG_CMD >> $LOG_FILE"
      or die qq^$::basename: unable to output data to "$LOG_CMD >> $LOG_FILE"$::EOM^;
    select LOG;

    my($key, $value) = ('','');
    while (($key, $value) = each %not_processed) {
      printf LOG "%-20s\t%3d\n", "$key", "$value";
    }
    close LOG;
  }
}
1;
__END__

