#To-do:
##0. Improve error handling - DONE
##1. Add getopts - DONE
##2. Think of a way to get rid of hard coding in _extractWeatherData
##3. Randomize date - DONE
##4. Add WeatherData Class - DONE
##5. Add unit test - DONE
##6. Add comments - DONE

use strict;
use warnings;
use Getopt::Long;
use WeatherDataSimulator;
use English qw(-no_match_vars);

BEGIN {
    push @INC, ".";
}

my ($noPositions, $simulator, $help, %fields, $weatherData);

GetOptions("positions=i" => \$noPositions, 'help|?' => \$help);
usage() if $help;

#To-do: Look at a way to externalize this
$fields{cityIDFile}     = "city.txt";
$fields{weatherAppID}   = "3c21399c04bb3ac01a55d45572e47a27";
$fields{weatherDataURL} = "htt://api.openweathermap.org/data/2.5/forecast/city?id=";
$fields{noPositions}    = $noPositions if defined $noPositions;

$simulator = new WeatherDataSimulator(\%fields);
$weatherData = $simulator->getWeatherData();

foreach my $instance (@{$weatherData}) {
    print $instance->toString(), "\n";
}

sub usage {
    print "\n Usage:- \n./$PROGRAM_NAME -positions 100(OPTIONAL PARAMETER)";
    exit;
}
