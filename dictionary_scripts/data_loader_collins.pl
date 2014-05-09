#!/usr/bin/perl

use strict;
use warnings;
use open qw/:std :utf8/;
use DBI;
use utf8;

###################################
my $dictionary_name = "Collins COBUILD Advanced Learner's English Dictionary";
my $dictionary_file = "../../data/dic/ini/Collins4.txt";
my $clean = 0; # DROP TABLE source : 1 = yes, 0 = no

my $db_name = 'Dictionary';
my $host = 'localhost';
my $login = 'root';
my $password = '';
###################################

my $dbh = DBI->connect("DBI:mysql:$db_name:$host;mysql_local_infile=1", $login, $password, {RaiseError => 1, PrintError => 0}) || die "$DBI::err($DBI::errstr)\n";

$dbh->do('DROP TABLE IF EXISTS `source_collins`') if $clean;
$dbh->do('CREATE TABLE IF NOT EXISTS `source_collins` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `dictionary` char(64) DEFAULT NULL,
        `keyword` char(128) DEFAULT NULL,
        `def_number` int(2)  DEFAULT NULL,
        `definition` text,
        PRIMARY KEY (`id`),
        KEY `keyword` (`keyword`)
    )DEFAULT CHARSET=utf8'
);
my $load = $dbh->prepare(q/LOAD DATA LOCAl INFILE ? INTO TABLE `source_collins` CHARACTER SET UTF8 FIELDS TERMINATED BY '\r' LINES TERMINATED BY '\r\r'/);

print "Data parsing...";
print " ok\nData loading...";
open (OUT, ">", "tmp.file") || die;
open(IN, "< $dictionary_file") || die;
while(<IN>) {
    chomp;
    my ($key, $body) = split("\t");
    $key =~ s/\<.\>//;
    $key =~ s/ *\<sup\> *(\d+) *\<\/sup\> *//;
    $key =~ s/&eacute;/é/g;
    $key =~ s/&agrave;/à/g;
    $key =~ s/&egrave;/è/g;
    $key =~ s/&acirc;/â/g;
    $key =~ s/&ntilde;/ñ/g;
    $key =~ s/&amp;/&/g;
    my $num = $1 ? $1 : '\N';
    print $key, "\n" if $body =~ m/\<.?p\>/;
    print OUT (join("\r", '\N', $dictionary_name, $key, $num, $body), "\r\r");
}
close OUT;
$load->execute('tmp.file');
unlink "tmp.file";

print "ok\n";
print "finished!\n";
