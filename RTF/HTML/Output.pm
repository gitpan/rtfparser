# Sonovision-Itep, Verdret 1998
use strict;
package RTF::HTML::Output;

use RTF::Control;
@RTF::HTML::Output::ISA = qw(RTF::Control);

# Application interface, could notably evolved
# todo:
# - table oriented output specification could be nice

# The following data structures are imported:
# $style: name of the current style or pseudo-style
# $event: start or end for the document event

# Events (examples):
# - style_change 
# - lineindent [sup|inf]
# With an associated start and end event:
# ul, b, i
# document 
# table 
# row 
# cell 

# Should be documented ;-)
# $text: text associated to the current style
# %char: 
# %symbol: 
# %do_on_event: 
# $newstyle: 
# See examples in the following code for a specific stylesheet
# Now you can define your own rules...

				# Some generic parameters
				# define character mappings
				# some values could be found in HTML::Entities.pm
				# or redefine the char() method
				# Examples: 
%char = qw(
	   periodcentered *
	   copyright      ©
	   registered     ®
	   section        §
	   paragraph      ¶
	   nobrkspace     \240
	   odieresis      ö
	   idieresis      &iuml
	   egrave         &egrave;
	   agrave         &agrave;
	   eacute         &eacute;
	   ecirc          &ecirc;
	  );  
				# add value to %symbol
$symbol{'~'} = '&nbsp;'; 
$symbol{'ldblquote'} = '&laquo;';
$symbol{'rdblquote'} = '&raquo;';

sub text {			# callback redefinition
  my $text = $_[1];
  $text =~ s/</&lt;/g;	
  $text =~ s/>/&gt;/g;	
  output($text);
}

my $N = "\n"; # Pretty-printing
my @listStack = ();

my $prePar;
my $postPar;

# perhaps use only the output() routine
my $TITLE_FLAG = 0;
my $LANG = 'fr';
%do_on_event = 
  (
   'document' => sub {		# Special action
     if ($event eq 'start') {
       output qq@<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML//EN">$N<html>$N@;
     } else {
       my $author = $info{author};
       my $creatim = $info{creatim};
       my $revtim = $info{revtim};
       while (@listStack) {
	 $style = pop @listStack;
	 output "</$style>$N";
       }
       $style = 'p';

       if ($LANG eq 'fr') {
	 output "<$style><b>Auteur</b> : $author</$style>\n" if $author;
	 output "<$style><b>Date de création</b> : $creatim</$style>\n" if $creatim;
	 output "<$style><b>Date de modification</b> : $revtim</$style>\n" if $revtim;
       } else {			# Default
	 output "<$style><b>Author</b> : $author</$style>\n" if $author;
	 output "<$style><b>Creation date</b>: $creatim</$style>\n" if $creatim;
	 output "<$style><b>Modification date</b>: $revtim</$style>\n" if $revtim;
       }
       output "</body>\n</html>\n";
     }
   },
				# Table processing
   'table' => sub {
     if ($event eq 'start') {	# actually not defined by RTF::Control
       #print "<table>$N";
     } else {
       output "<table>$N$text</table>$N";
     }
   },
   'row' => sub {
     if ($event eq 'start') {	# not defined
       #print "$N<tr valign='top'>";
     } else {
       output "$N<tr valign='top'>$text</tr>$N";
     }
   },
   'cell' => sub {
     if ($event eq 'start') {	# not defined
       #output "<td>";
     } else {
       output "<td>$text</td>$N";
     }
   },
   'Normal' => sub {
     return output($text) unless $text =~ /\S/;
     if ($par{'bullet'}) {	# Heuristic rules
       $style = 'LI';
     } elsif ($par{'number'}) { 
       $style = 'LI';
     } else {
       $style = 'p';
     }
     output "<$style>$text</$style>\n";
     #$style = 'p';
     #print "<$style>$text</$style>\n";
   },
   'b' => sub {			
     $style = 'b';
     if ($event eq 'end') {
       output "</$style>";
     } else {
       output "<$style>";
     }
   },
   'ul' => sub {			
     $style = 'em';
     if ($event eq 'end') {
       output "</$style>";
     } else {
       output "<$style>";
     }
     
   },
   'i' => sub {
     $style = 'i';
     if ($event eq 'end') {
       output "</$style>";
     } else {
       output "<$style>";
     }
   },
   'sub' => sub {
     $style = 'sub';
     if ($event eq 'end') {
       output "</$style>";
     } else {
       output "<$style>";
     }
   },
   'super' => sub {
     $style = 'sup';
     if ($event eq 'end') {
       output "</$style>";
     } else {
       output "<$style>";
     }
   },
   'par' => sub {	
     my $m;
     if ($par{'bullet'}) {	# Heuristic rules
       $style = 'LI';
     } elsif ($par{'number'}) { 
       $style = 'LI';
     } else {
       $style = 'p';
     }
     output "$N<$style>$text</$style>$N";
   },
  );
1;
__END__

				# HEURISTIC PART
   'lineindent' => sub {	# Liste indent
     if ($event eq 'sup') {	# Open lists
       return if ($style eq 'List Bullet');
       if ($par{'bullet'}) {	# what kind of list?
	 $style = 'UL';
	 push @listStack, $style;
	 $prePar = "<$style>" if $style;
	 print STDERR "bullet: $prePar\n";
       } elsif ($par{'number'}) {
	 $style = "OL start=$par{'number'}";
	 push @listStack, $style;
	 $prePar = "<$style>" if $style;
	 print STDERR "number: $prePar\n";
       } else {
	 push @listStack, '';
	 $prePar = '';
	 print STDERR "NOTHING!\n";
       }
       output "$prePar$N";
     } elsif ($event eq 'inf') { # Close list
       if ($par{'lineindent'} == 0) { # 'pard' reset
	 $prePar = '';
	 while (@listStack) {
	   $style = shift @listStack;
	   $prePar .= "</$style>\n" if $style;
	 }
	 print STDERR "=>$prePar<=\n";
	 output "$prePar$N";
       } else {
	 if (@listStack) {
	   $style = shift @listStack;
	   $prePar = "</$style>\n" if $style;
	   print STDERR "=>$prePar<=\n";
	 }
	 output "$prePar$N";
       }
     }
   },
   'style_change' => sub {	# A special event on tag changing
     if ($newstyle eq 'List Bullet') {
       $style = 'UL';
       push @listStack, $style;
       output "<$style>$N";
     } elsif ($style eq 'List Bullet') {
       $style = pop @listStack;
       output "</$style>$N";
     }
   },

