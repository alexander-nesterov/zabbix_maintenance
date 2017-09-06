#!/usr/bin/perl

#https://www.zabbix.com/documentation/3.0/manual/api/reference/maintenance/create

use strict;
use warnings;
use LWP::UserAgent;
use JSON qw(encode_json decode_json);
use Data::Dumper;

#================================================================
#Constants
#================================================================
#ZABBIX
use constant ZABBIX_USER	=> 'Admin';
use constant ZABBIX_PASSWORD	=> 'password';
use constant ZABBIX_SERVER	=> 'localhost';

#================================================================
#Global variables
#================================================================
my $ZABBIX_AUTH_ID;

main();

#================================================================
sub zabbix_auth
{
    my %data;

    $data{'jsonrpc'} = '2.0';
    $data{'method'} = 'user.login';
    $data{'params'}{'user'} = ZABBIX_USER;
    $data{'params'}{'password'} = ZABBIX_PASSWORD;
    $data{'id'} = 1;

    my $response = send_to_zabbix(\%data);

    $ZABBIX_AUTH_ID = get_result($response);
    do_print('Auth ID: ' . $ZABBIX_AUTH_ID, 'SUCCESS');
}

#================================================================
sub zabbix_logout
{
    my %data;

    $data{'jsonrpc'} = '2.0';
    $data{'method'} = 'user.logout';
    $data{'params'} = [];
    $data{'auth'} = $ZABBIX_AUTH_ID;
    $data{'id'} = 1;

    my $response = send_to_zabbix(\%data);

    my $result = get_result($response);
    do_print("Logout: $result", 'SUCCESS');
}

#================================================================
sub send_to_zabbix
{
    my $data_ref = shift;

    my $json = encode_json($data_ref);
    my $ua = create_ua();

    my $response = $ua->post('http://' . ZABBIX_SERVER . '/api_jsonrpc.php',
    			     'Content_Type' => 'application/json',
    			     'Content' => $json,
    			     'Accept' => 'application/json');
    if ($response->is_success)
    {
    	my $content_decoded = decode_json($response->content);
    	if (is_error($content_decoded))
    	{
	    do_print('Error: ' . get_error($content_decoded), 'ERROR');
	    exit(-1);
    	}
	return $content_decoded;
    }
    else
    {
	do_print('Error: ' . $response->status_line, 'ERROR');
	exit(-1);
    }
}

#================================================================
sub get_name_by_id
{
    my $hosts_names_ref = shift;

    my %data;
    $data{'jsonrpc'} = '2.0';
    $data{'method'} = 'host.get';
    $data{'params'}{'output'} = ['hostid'];
    $data{'params'}{'filter'}{'host'} = [@$hosts_names_ref];
    $data{'auth'} = $ZABBIX_AUTH_ID;
    $data{'id'} = 1;

    my @hosts;
    my $response = send_to_zabbix(\%data);
    foreach my $id (@{$response->{'result'}})
    {
    	push(@hosts, int($id->{'hostid'}));
    }
    return @hosts;
}

#================================================================
sub create_maintenance
{
    my ($name,             #Название обслуживания
    	$since,            #Активно с
    	$till,             #Активно до
    	$description,      #Описание
    	$maintenance_type, #Тип обслуживания
    	@hosts_names,      #Список узлов сети в обслуживании
    ) = @_;

    #Получаем список узлов
    my @hosts_id = get_name_by_id(\@hosts_names);

    if (scalar @hosts_id == 0)
    {
    	do_print('Array of hosts is empty', 'INFO');
    	return;
    }

    my %data;
    $data{'jsonrpc'} = '2.0';
    $data{'method'} = 'maintenance.create';
    $data{'params'}{'name'} = $name;
    $data{'params'}{'active_since'} = $since;
    $data{'params'}{'active_till'} = $till;
    $data{'params'}{'description'} = $description;
    $data{'params'}{'maintenance_type'} = $maintenance_type; #0 - (по умолчанию) со сбором данных; 1 - без сбора данных.
    $data{'params'}{'hostids'} = [@hosts_id];
    $data{'params'}{'groupids'} = [];

    $data{'params'}{'timeperiods'}[0]{'timeperiod_type'} = 0;
    $data{'params'}{'timeperiods'}[0]{'every'} = 1;
    $data{'params'}{'timeperiods'}[0]{'month'} = 0;
    $data{'params'}{'timeperiods'}[0]{'dayofweek'} = 64;
    $data{'params'}{'timeperiods'}[0]{'day'} = 0;
    $data{'params'}{'timeperiods'}[0]{'start_time'} = 43200;
    $data{'params'}{'timeperiods'}[0]{'start_date'} = 1504371600;
    $data{'params'}{'timeperiods'}[0]{'period'} = 3600;

    $data{'auth'} = $ZABBIX_AUTH_ID;
    $data{'id'} = 1;

    my $response = send_to_zabbix(\%data);
}

#================================================================
sub is_error
{
    my $content = shift;

    if ($content->{'error'})
    {
	return 1;
    }
    return 0;
}

#================================================================
sub get_result
{
    my $content = shift;

    return $content->{'result'};
}

#================================================================
sub get_error
{
    my $content = shift;

    return $content->{'error'}{'data'};
}

#================================================================
sub create_ua
{
    my $ua = LWP::UserAgent->new();

    return $ua;
}

#================================================================
sub colored
{
    my ($text, $color) = @_;

    my %colors = ('black'   => 30,
                  'red'     => 31,
                  'green'   => 32,
                  'yellow'  => 33,
                  'blue'    => 34,
                  'magenta' => 35,
	          'cyan'    => 36,
                  'white'   => 37
    );
    my $c = $colors{$color};
    return "\033[" . "$colors{$color}m" . $text . "\e[0m";
}

#================================================================
sub do_print
{
    my ($text, $level) = @_;

    my %lev = ('ERROR'   => 'red',
    	       'SUCCESS' => 'green',
    	       'INFO'    => 'yellow'
    );
    print colored("$text\n", $lev{$level});
}

#================================================================
sub main
{
    zabbix_auth();
    my @hosts_names = ('Zabbix server', 'proxy.teh-in.com');
    create_maintenance('test', 
                       1511308800, 
		       1511568000, 
		       'Descriprion', 
		       0, 
		       @hosts_names);
    zabbix_logout();
}
