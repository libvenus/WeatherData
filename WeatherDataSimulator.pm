package WeatherDataSimulator;

use strict;
use warnings;
use Moose;
use Carp;
use JSON;
use Try::Tiny;
use LWP::UserAgent;
use POSIX qw(strftime);
use Unicode::Normalize;
use LWP::Protocol::https;
use HTTP::Request::Common;
use English qw(-no_match_vars);

use WeatherData;

has 'cityIDFile' => (
	is => 'ro',
	isa => 'Str',
	required => 1
);

has 'noPositions' => (
	is => 'ro',
	isa => 'Int',
	default => 10
);

has 'cityIDs' => (
	is   => 'rw',
	isa  => 'HashRef',
	lazy => 1,
	required => 1,
	builder  => '_setCityIDs'
);

has 'weatherDataURL' => (
	is   => 'ro',
	isa  => 'Str',
	required => 1
);

has 'weatherAppID' => (
	is   => 'ro',
	isa  => 'Str',
	required => 1
);

#Private method to populate the cityIDs
sub _setCityIDs {
	my $this = shift;
	my $file = $this->cityIDFile();
	my $jsonParser = new JSON();
	my (%cityIDs, $FH, $cityNO, $noPositions, $json, $content, $WFH);
	
	try {
		open $FH, "<", $file or die $OS_ERROR;
		$cityNO = 0, $noPositions = $this->noPositions();
		while (<$FH>) {
			my $line = $_;
			my $randCityKey = int(rand(50000)); #Introduce some randomness
			my @cityDetails
				= $line =~ /^.+?\:(\d+)\,.+?\:(.+?)\,.+?\,.+?\:.+?\:(.+?)\,.+?\:(.+?)\}/;
			
			$cityIDs{$randCityKey} = \@cityDetails;
			
			$cityNO++;
			last if $cityNO == $noPositions;
		}
		close $FH;
	} catch  {
		print $json, "\n";
		print $EVAL_ERROR;
		exit;
	};

	$this->cityIDs(\%cityIDs);
}

#Public method that connects to a Web API that provides Geo and weather data
sub getWeatherData {
	my $this = shift;
	my $userAgent = new LWP::UserAgent();
	my $jsonParser = new JSON();
	my $ct = "application/json";
	my ($url, $res, %cityIDs, $json, @weatherData, @all, $errorFlag);
	
	%cityIDs = %{$this->cityIDs()};	
	foreach my $cityDetails (values %cityIDs) {
		last if defined $errorFlag;
		$url = $this->weatherDataURL().$cityDetails->[0]."&APPID=".$this->weatherAppID();
	    try {
			$res = $userAgent->get($url);
			$json = $jsonParser->decode($res->content());
			push @weatherData, $this->_extractWeatherData($json);
		} catch {
			$errorFlag = 1;
		};
	}
	
	return $this->_cookWeatherData() if defined $errorFlag;
	return \@weatherData;
}

#Private method to cook weather data if we are not able to do so via the web API
#If the city is near equator(abs(lat) > 45) and is near the coast the weather
#should in general be hot and humid depending on which part of the year we are in.
#In general, if we are in period Mar-Oct it should be hot else cold, specially for
#countries near the equator. Also, temperature has direct relationship with pressure.
#The relative humidity is also directely proportinal provided the city is near coast
#or waterbodies which can ingest more moisture in the air. Tempeature, pressure and
#relative humidity can be used to correlate and predict conditions.
sub _cookWeatherData {
	my $this = shift;
	my ($res, %cityIDs, @weatherData, @all, $instance);
	my %map = (0 => '+', 1 => '-');
	
	%cityIDs = %{$this->cityIDs()};	
	foreach my $cityDetails (values %cityIDs) {
		my ($id, $name, $lon, $lat) = @{$cityDetails};
		my ($randSecs, @dateTime, $month, $cond, $temp, $pres, $hum, $localTime);
		
		$name =~ s/\"//g;
		$randSecs = int(rand(240) + 240) * 3600 * 24; #Randomize date
		@dateTime =  localtime(time - $randSecs);
		$localTime = strftime "%Y-%m-%dT%H:%M:%SZ", @dateTime;
		$month = $dateTime[4] + 1; #Jan is 0
		$lat = abs($lat);
		if ($lat > 45) {#close to equator; logic could also be based on $temp
			if ($month >= 3 && $month <= 10) {#warm period
				if ($month >= 3 && $month <= 6) {#just warm
					$temp = 43.32 + int(rand(6)); $hum = 70 + int(rand(8)); $cond = "Sunny";
				} elsif ($month >= 7 && $month <= 8) { #warm and rainy season 
					$temp = int(rand(1)) == 0 ?  40.50 - int(rand(5)) : 40.50 + int(rand(2));
					$hum = 90 + int(rand(8)); $cond = "Rain";														  
				} else {#less warm
					$temp = 43.24 - int(rand(5)); $hum = 70 + int(rand(5)); $cond = "Sunny";
				}
			} else {#cold period
				if ($month == 11 || $month == 2) {#just warm
					$temp = 30.30 + int(rand(6)); $hum = 60 + int(rand(8)); $cond = "Sunny";
				} else {
					$temp = int(rand(1)) == 0 ?  4.00 - int(rand(5)) : 5.00 + int(rand(2));
					$hum = 5 + int(rand(8)); $cond = $temp < 0 ? "Snow" : "Sunny";
				}
			}
			$pres = $temp > 40 ? 1000.30 + int(rand(50)) : 1000.25 - int(rand(50));
		} else {#Away from equator so cooler
			$temp =  int(rand(1)) == 0 ?  4 - int(rand(5)) : 5 + int(rand(2));
			$hum = 5 + int(rand(8)); $cond = $temp < 0 ? "Snow" : "Sunny";
			$pres = $temp > 5 ? 930.66 + int(rand(50)) : 1000 - int(rand(50));
		}

		$instance = new WeatherData({
			location => $name, position => "$lon,$lat",
			localtime => $localTime, temperature => $temp,
			pressure => $pres, humidity => $hum, conditions => $cond
		});
	
		push @weatherData, $instance;
	}
	
	return \@weatherData;
}
#Private method leveraged to extract relevant Geo and Weather data
#TODO - the json element lookup needs to be externalized to make the code
#more maintainable and robust.
sub _extractWeatherData {
	my $this = shift;
	my $json = shift;
	my (@weatherData, %fields, $location, $position, $localTime, $conditions,
		$temperature, $pressure, $humidity, $randSecs);
	
	$randSecs = int(rand(3)) * 3600 * 24; #Randomize date
	
	$fields{location} = exists $json->{city}->{name} ? $json->{city}->{name} : return;
	$fields{position} = (exists $json->{city}->{coord}->{lat} && exists $json->{city}->{coord}->{lon})
				        ? $json->{city}->{coord}->{lat}.",".$json->{city}->{coord}->{lon} : return;
	$fields{localtime} = exists $json->{list}->[0]->{dt} ? $json->{list}->[0]->{dt} : return;
	$fields{localtime} = strftime "%Y-%m-%dT%H:%M:%SZ", localtime($fields{localtime} - $randSecs);
	$fields{temperature} = exists $json->{list}->[0]->{main}->{temp}
					       ? $json->{list}->[0]->{main}->{temp} : return;
	$fields{temperature} = $fields{temperature} - 273.15;
	$fields{pressure} = exists $json->{list}->[0]->{main}->{pressure}
					    ? $json->{list}->[0]->{main}->{pressure} : return;
	$fields{humidity} = exists $json->{list}->[0]->{main}->{humidity}
					    ? $json->{list}->[0]->{main}->{humidity} : return;
	if (exists $json->{list}->[0]->{weather}->[0]->{main}) {
		if ($json->{list}->[0]->{weather}->[0]->{main} =~ /cloud/i) {
			$fields{conditions} = "Snow";
		} elsif ($json->{list}->[0]->{weather}->[0]->{main} =~ /rain/i) {
			$fields{conditions} = "Rain";
		} elsif ($json->{list}->[0]->{weather}->[0]->{main} =~ /clear/i) {
			$fields{conditions} = "Sunny";
		} else {
			return;
		}
	} else {
		return;
	}
	
	return new WeatherData(\%fields);
}

__PACKAGE__->meta->make_immutable;

1;
