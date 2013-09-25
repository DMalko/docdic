#!/usr/bin/perl

use strict;
use warnings;

use LWP::UserAgent;
use IO::Socket::SSL;
use Mozilla::CA;

###################################
my $infile = "../words.txt";
my $dictionary = 'GoogleRuEn_Jul2013';
my $source = 'ru';
my $target = 'en';
my $google = 'https://translate.google.ru/translate_a/t?client=t&hl=en&sl=&tl=&ie=UTF-8&oe=UTF-8&oc=1&otf=2&rom=1&ssel=0&tsel=0&sc=1&q=';
my $check = 0; # check ca_ssl_file
###################################

# check sertificate ###############
if ($check) { 
    my $host = "google.ru";
    my $sert = Mozilla::CA::SSL_ca_file();
    my $client = IO::Socket::SSL->new(
        PeerHost => "$host:443",
        SSL_verify_mode => 0x02,
        SSL_ca_file => Mozilla::CA::SSL_ca_file(),
        )
        || die "Can't connect: $@";
    
    $client->verify_hostname($host, "http")
        || die "hostname verification failure";
}
###################################

$google =~ s/sl=/sl=$source/;
$google =~ s/tl=/tl=$target/;

my $ua = LWP::UserAgent->new(ssl_opts => {verify_hostname => 0});
$ua->agent("Mozilla/0.1");
$ua->ssl_opts(SSL_ca_file => Mozilla::CA::SSL_ca_file());

open (IN, "<", $infile) || die;
open(OUT, ">", $infile.'.google') || die;
my $n = 0;
while (my $word = <IN>) {
    chomp $word;
    my $rqst = $google.$word;
    my $request = HTTP::Request->new(GET => $rqst);
    my $res = $ua->request($request);
    while ($res->{_rc} != 200) {
        sleep 2;
        $res = $ua->request($request);
    }
    my $content = $res->{_content};
    if ($content !~ m/^\[/) {
        die "ERROR:\n$content\n";
    }
    print OUT join("\t", '\N', $dictionary, $word, $content), "\n";
    print $n++, ' ', $content, "\n";
    #sleep 2;
}
close IN;
close OUT;
print "finished!\n";

#load data local infile 'my_data.txt' into table my_data character set UTF8

