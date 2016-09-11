package WeatherData;

use strict;
use warnings;

use Moose;

has 'location' => (
	is => 'ro',
	isa => 'Str',
	required => 1
);

has 'position' => (
	is => 'ro',
	isa => 'Str',
	required => 1
);

has 'localtime' => (
	is => 'ro',
	isa => 'Str',
	required => 1
);

has 'conditions' => (
	is => 'ro',
	isa => 'Str',
	required => 1
);

has 'temperature' => (
	is => 'ro',
	isa => 'Str',
	required => 1
);

has 'pressure' => (
	is => 'ro',
	isa => 'Str',
	required => 1
);

has 'humidity' => (
	is => 'ro',
	isa => 'Str',
	required => 1
);

sub toString {
    my $this = shift;
    my ($loc, $pos, $lTime, $cond, $temp, $pres, $humi);
    
    $loc   = $this->location();
    $pos   = $this->position();
    $lTime = $this->localtime();
    $cond  = $this->conditions();
    $temp  = $this->temperature();
    $pres  = $this->pressure();
    $humi  = $this->humidity();
    
    return $loc."|".$pos."|".$lTime."|".$cond."|".$temp."|".$pres."|".$humi;
}

__PACKAGE__->meta->make_immutable;

1;