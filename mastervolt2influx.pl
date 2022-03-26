#!/usr/bin/perl
use InfluxDB::LineProtocol qw(data2line);
use LWP::UserAgent;
use HTTP::Request::Common;
use Date::Parse;
#Pfad zur seriellen Schnittstelle oder dem USB-Seriell-Wandler:
my $schnittstelle = '/dev/ttyUSB0';

#Weitere Variablen die benoetigt werden -> NICHT veraendern!

my $seriel;
my $sin; #Serial Input = Empangener Datenstrom
my $cin; #Counter Input =  Länge des Datenpackets
my $exit;
my $reciv;
my $daten;
my $return_value2;
my $influxdb ='solar';
my $influxhost = '<URL GRAFANASERVER>';
my $influxuser;
my $influxpass;
my $debug=0;
my $Zaehler = 200;

use Time::Local;
$mode = "grafanfa";
sub plugin_log{
        $n = scalar(@_);
        $sum = 0;
        foreach $item(@_) {
                $sum += $item;
                print "$item  \n";
        }
}

$plugin_info{$plugname.'_cycle'}  = 30;
use Device::SerialPort;

       $seriel = Device::SerialPort->new($schnittstelle) || die "Kann $schnittstelle nicht öffnen! ($!)\n";
       $seriel->baudrate(9600);
       $seriel->parity("none");
       $seriel->databits(8);
       $seriel->stopbits(1);
       if($debug>=1){plugin_log($plugname,'Schnittstelle: ' . $schnittstelle . ' erfolgreich geöffnet')};
       $daten = "a001ffffb600000055";

while () {
        $return_value2 = command_senden($daten);
        sleep(120);
        }
sub command_senden{
    my $data = $_[0];
    my $command = pack("H*",$data);

    $seriel->write($command);

    $reciv = '';
    $cin = '';
    $sin = '';

    $|=1;
    my $exit=0;
    while($exit < $Zaehler)
    {
        ($cin, $sin) = $seriel->read(45);

        if($cin > 0){
            $sin = unpack "H*", $sin;
            $reciv .= $sin;
            $exit=0;
}else{
            $exit++
        }

        if($debug>=3){plugin_log($plugname,'reciv-direkt: ' . $sin);}

    }#Ende While
    if($debug>=2){plugin_log($plugname,'reciv-komplet: ' . $reciv);}

    my $len = length($data);

    if(substr($reciv,0,$len) eq $data){

        $reciv =~ s/$data//;
        if($debug>=2){plugin_log($plugname,'reciv gekürzt: ' . $reciv);}

        my @array = map "$_", $reciv =~ /(..)/g;
       #print(@array);
        my $pv_voltage = $array[9] . $array[8];
        if($debug>=2){plugin_log($plugname,'substr: ' . $pv_voltage);}
        $pv_voltage =  hex($pv_voltage);
        if($debug>=1){plugin_log($plugname,'PV Spannung: ' . $pv_voltage . 'V');}


        my $pv_ampere = $array[11] . $array[10];
        if($debug>=2){plugin_log($plugname,'substr: ' . $pv_ampere);}
        $pv_ampere =  hex($pv_ampere)/100;
        if($debug>=1){plugin_log($plugname,'PV Strom: ' . $pv_ampere . 'A');}

        my $pv_frequecy = $array[13] . $array[12];
        if($debug>=2){plugin_log($plugname,'substr: ' . $pv_frequecy);}
        $pv_frequecy =  hex($pv_frequecy)/100;
        if($debug>=1){plugin_log($plugname,'PV Frequenz: ' . $pv_frequecy . 'Hz');}

        my $pv_grid_voltage = $array[15] . $array[14];
        if($debug>=2){plugin_log($plugname,'substr: ' . $pv_grid_voltage);}
        $pv_grid_voltage =  hex($pv_grid_voltage);
        if($debug>=1){plugin_log($plugname,'PV Ausgangsspannung: ' . $pv_grid_voltage . 'V');}

        my $pv_grid_power = $array[19] . $array[18];
        if($debug>=2){plugin_log($plugname,'substr: ' . $pv_grid_power);}
        $pv_grid_power =  hex($pv_grid_power);
        if($debug>=1){plugin_log($plugname,'PV Ausgangsleistung: ' . $pv_grid_power . 'W');}

        my $pv_total_grid_power = $array[22] . $array[21] . $array[20];
        if($debug>=2){plugin_log($plugname,'substr: ' . $pv_total_grid_power);}
        $pv_total_grid_power =  hex($pv_total_grid_power)*100;
        if($debug>=1){plugin_log($plugname,'PV total Ausgangsleistung: ' . ($pv_total_grid_power/1000) . 'kWh');}

        my $pv_temp = $array[23];
        if($debug>=2){plugin_log($plugname,'substr: ' . $pv_temp);}
        $pv_temp =  hex($pv_temp);
        if($debug>=1){plugin_log($plugname,'PV Temperatur: ' . $pv_temp . '°C');}

        my $pv_working_time = $array[27] . $array[26] . $array[25] . $array[24];
        if($debug>=2){plugin_log($plugname,'substr: ' . $pv_working_time);}
        $pv_working_time =  hex($pv_working_time)/60;
        if($debug>=1){plugin_log($plugname,'PV Betriebsstunden: ' . $pv_working_time . 'h');}
        if ( $mode = "grafana" ) {
                my $timestampf = time;
                $influxreq = data2line("xs3200,tag=solar pvu=$pv_voltage,pvi=$pv_ampere,pvw=$pv_grid_power,pvkwh=$pv_total_grid_power,pvt=$pv_temp,pvf=$pv_frequecy,pvr=$pv_working_time") ;
                my $ua = LWP::UserAgent->new();
                my $request = POST $influxhost . '/write?precision=ns&db=' . $influxdb, Content => $influxreq;
                if ($influxuser && $influxpass) {
                            $request->authorization_basic($influxuser, $influxpass);
                }
                my $response = $ua->request($request);
                if (!($response->is_success) || ($debug>1)) {
                        print "$influxreq \n";
                        print $response->status_line . "\n" . $response->headers()->as_string;    # HTTP 204 is ok
                }
                }

        }else{
        if($debug>=2){plugin_log($plugname,'Falsche Antwort auf: ' . $data);}
    }
}
    
