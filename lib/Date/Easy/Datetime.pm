package Date::Easy::Datetime;

use strict;
use warnings;
use autodie;

# VERSION

use Exporter;
use parent 'Exporter';
our @EXPORT_OK = qw< datetime now >;
our %EXPORT_TAGS = ( all => \@EXPORT_OK );

use Carp;
use Time::Local;
use Time::Piece;
use Scalar::Util 'blessed';


# this can be modified (preferably using `local`) to use GMT/UTC as the default
# or you can pass a value to `import` via your `use` line
our $DEFAULT_ZONE = 'local';

my %ZONE_FLAG = ( local => 1, UTC => 0, GMT => 0 );


sub import
{
	my @args;
	exists $ZONE_FLAG{$_} ? $DEFAULT_ZONE = $_ : push @args, $_ foreach @_;
	@_ = @args;
	goto &Exporter::import;
}


##############################
# FUNCTIONS (*NOT* METHODS!) #
##############################

sub datetime
{
	my $zonespec = @_ % 2 == 0 ? shift : $DEFAULT_ZONE;
	my $datetime = shift;
	if ( $datetime =~ /^-?\d+$/ )
	{
		return Date::Easy::Datetime->new($zonespec, $datetime);
	}
	else
	{
		my $t = _str2time($datetime, $zonespec);
		$t = _parsedate($datetime, $zonespec) unless defined $t;
		croak("Illegal datetime: $datetime") unless defined $t;
		return Date::Easy::Datetime->new( $zonespec, $t );
	}
	die("reached unreachable code");
}

sub now () { Date::Easy::Datetime->new }


sub _str2time
{
	require Date::Parse;
	my ($time, $zone) = @_;
	return Date::Parse::str2time($time, $zone eq 'local' ? () : $zone);
}

sub _parsedate
{
	require Time::ParseDate;
	my ($time, $zone) = @_;
	return scalar Time::ParseDate::parsedate($time, $zone eq 'local' ? () : (GMT => 1));
}


#######################
# REGULAR CLASS STUFF #
#######################

sub new
{
	my $class = shift;
	my $zonespec = @_ == 2 || @_ == 7 ? shift : $DEFAULT_ZONE;
	croak("Unrecognized timezone specifier") unless exists $ZONE_FLAG{$zonespec};

	my $t;
	if (@_ == 0)
	{
		$t = time;
	}
	elsif (@_ == 6)
	{
		my ($y, $m, $d, $H, $M, $S) = @_;
		--$m;										# timelocal/timegm will expect month as 0..11
		$t = $zonespec eq 'local' ? timelocal($S, $M, $H, $d, $m, $y) : timegm($S, $M, $H, $d, $m, $y);
	}
	elsif (@_ == 1)
	{
		$t = shift;
		if ( blessed $t and $t->isa('Time::Piece') )
		{
			# it's already what we were going to construct anyway;
			# just stick it in a hash and call it a day
			return bless { impl => $t }, $class;
		}
	}
	else
	{
		croak("Illegal number of arguments to datetime()");
	}

	bless { impl => scalar Time::Piece->_mktime($t, $ZONE_FLAG{$zonespec}) }, $class;
}


sub is_local {  shift->{impl}->[Time::Piece::c_islocal] }
sub is_gmt   { !shift->{impl}->[Time::Piece::c_islocal] }
*is_utc = \&is_gmt;


sub as
{
	my ($self, $newclass) = @_;

	if ($newclass eq 'Time::Piece')
	{
		return $self->{impl};
	}
}


sub year		{ shift->{impl}->year }
sub month		{ shift->{impl}->mon }
sub day			{ shift->{impl}->mday }
sub hour		{ shift->{impl}->hour }
sub minute		{ shift->{impl}->min }
sub second		{ shift->{impl}->sec }
sub epoch		{ shift->{impl}->epoch }
sub day_of_week	{ shift->{impl}->day_of_week || 7 }						# change Sunday from 0 to 7
sub quarter		{ int(shift->{impl}->_mon / 3) + 1 }					# calc quarter from (zero-based) month

sub strftime	{ shift->{impl}->strftime(@_) }

1;

# ABSTRACT: easy datetime class
# COPYRIGHT
