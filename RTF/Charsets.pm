# need to be improved!!!
use strict;
package RTF::Charsets;
use Exporter;
use vars qw(@ISA @EXPORT);
@ISA = qw(Exporter);
use vars qw(%ansi %pc);
@EXPORT = qw(%ansi %pc);

my %ansi_chars = qw(
	   nobrkspace	a0
	   exclamdown	a1
	   cent		a2
	   sterling	a3
	   currency	a4
	   yen		a5
	   brokenbar	a6
	   section		a7
	   dieresis	a8
	   copyright	a9
	   ordfeminine	aa
	   guillemotleft	ab
	   logicalnot	ac
	   opthyphen	ad
	   registered	ae
	   macron		af
	   degree		b0
	   plusminus	b1
	   twosuperior	b2
	   threesuperior	b3
	   acute		b4
	   mu		b5
	   paragraph	b6
	   periodcentered	b7
	   cedil		b8
	   onesuperior	b9
	   ordmasculine	ba
	   guillemotright	bb
	   onequarter         bc
	   onehalf		bd
	   threequarters	be
	   questiondown	bf
	   Agrave		c0
	   Aacute		c1
	   Acirc	c2
	   Atilde		c3
	   Adieresis	c4
	   Aring		c5
	   AE		c6
	   Ccedil	c7
	   Egrave		c8
	   Eacute		c9
	   Ecirc	ca
	   Edieresis	cb
	   Igrave		cc
	   Iacute		cd
	   Icirc	ce
	   Idieresis	cf
	   Eth		d0
	   Ntilde		d1
	   Ograve		d2
	   Oacute		d3
	   Ocirc	d4
	   Otilde		d5
	   Odieresis	d6
	   multiply	d7
	   Oslash		d8
	   Ugrave		d9
	   Uacute		da
	   Ucirc	db
	   Udieresis	dc
	   Yacute		dd
	   Thorn		de
	   germandbls	df
	   agrave		e0
	   aacute		e1
	   acirc	e2
	   atilde		e3
	   adieresis	e4
	   aring		e5
	   ae		e6
	   ccedil	e7
	   egrave		e8
	   eacute		e9
	   ecirc	ea
	   edieresis	eb
	   igrave		ec
	   iacute		ed
	   icirc	ee
	   idieresis	ef
	   eth		f0
	   ntilde		f1
	   ograve		f2
	   oacute		f3
	   ocirc	f4
	   otilde		f5
	   odieresis	f6
	   divide		f7
	   oslash		f8
	   ugrave		f9
	   uacute		fa
	   ucirc	fb
	   udieresis	fc
	   yacute		fd
	   thorn		fe
	   ydieresis	ff
	  );
my %pc_chars = qw(
	 Ccedil	80
	 udieresis	81
	 eacute	82
	 acirc	83
	 adieresis	84
	 agrave	85
	 aring		86
	 ccedil	87
	 ecirc	88
	 edieresis	89
	 egrave		8a
	 idieresis	8b
	 icirc	8c
	 igrave		8d
	 Adieresis	8e
	 Aring		8f
	 Eacute		90
	 ae		91
	 AE		92
	 ocirc	93
	 odieresis	94
	 ograve		95
	 ucirc	96
	 ugrave		97
	 ydieresis	98
	 Odieresis	99
	 Udieresis	9a
	 cent		9b
	 sterling	9c
	 yen		9d
	 ucirc	9e
	 florin		9f
	 aacute		a0
	 iacute		a1
	 oacute		a2
	 uacute		a3
	 ntilde		a4
	 Ntilde		a5
	 ordfeminine	a6
	 ordmasculine	a7
	 questiondown	a8
	 copyright	a9
	 trademark	aa
	 acute		ab
	 dieresis	ac
	 exclamdown	ad
	 guillemotleft	ae
	 guillemotright	af
	 space		b0
	 plusminus	b1
	 lessequal	b2
	 bar		b3
	 yen		b4
	 mu		b5
	 partialdiff	b6
	 Sigma		b7
	 Pi		b8
	 pi		b9
	 integral	ba
	 ordfeminine	bb
	 ordmasculine	bc
	 Omega		bd
	 ae		be
	 logicalnot	bf
	 questiondown	c0
	 exclamdown	c1
	 logicalnot	c2
	 radical		c3
	 emdash		c4
	 approxequal	c5
	 delta		c6
	 guillemotleft	c7
	 guillemotright	c8
	 ellipsis	c9
	 nobrkspace	ca
	 Agrave		cb
	 Atilde		cc
	 Otilde		cd
	 OE		ce
	 oe		cf
	 endash		d0
	 emdash		d1
	 quotedblleft	d2
	 quotedblright	d3
	 quoteleft	d4
	 quoteright	d5
	 divide		d6
	 lozenge		d7
	 ydieresis	d8
	 Ydieresis	d9
	 fraction	da
	 Ydieresis	db
	 guilsinglleft	dc
	 greater		dd
	 less		de
	 fl		df
	 a		e0
	 germandbls	e1
	 quotesinglbase	e2
	 pi		e3
	 Sigma		e4
	 Acirc	e5
	 mu		e6
	 Aacute		e7
	 Edieresis	e8
	 Egrave		e9
	 Omega		ea
	 partialdiff	eb
	 infinity	ec
	 oslash		ed
	 e		ee
	 Ocirc 	ef
	 equal		f0
	 plusminus	f1
	 greaterequal	f2
	 lessequal	f3
	 integral	f4
	 integral	f5
	 divide		f6
	 approxequal	f7
	 degree	f8
	 bullet	f9
	 bullet	fa
	 radical	fb
	 cedil	fc
	 hungarumlaut	fd
	 ogonek	fe
	 nbsp	ff
	);
%ansi = reverse %ansi_chars;
%pc = reverse %pc_chars;

1;
__END__
#@EXPORT = qw(entities2pc pc2entities %entities2pc %pc2entities);
#sub pc2entities { "$pc2entities{$_[0]}" }
#sub entities2pc {
#  my $char = $_[0];
#  #$char =~ s/&(.+);//;
#  "\\'$entities2pc{$char}";
#}
