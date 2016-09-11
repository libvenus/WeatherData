#Basic test case - weatherdata01.t
#Just checks if we are receiving some weather data.
#Other tests can go into minute details

use strict;
use warnings;
use WeatherDataSimulator;
use Test::More tests => 1;

my ($noPositions, $simulator, $help, %fields, $weatherData, $expected, $got);

$fields{cityIDFile}     = "city.txt";
$fields{weatherAppID}   = "3c21399c04bb3ac01a55d45572e47a27";
$fields{weatherDataURL} = "http://api.openweathermap.org/data/2.5/forecast/city?id=";
$fields{noPositions}    = $noPositions if defined $noPositions;

$simulator = new WeatherDataSimulator(\%fields);
$weatherData = $simulator->getWeatherData();

$got = 1 if @{$weatherData} > 0;
$expected = 1;

is($got, $expected, "Got some Weather data!!");