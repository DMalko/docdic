#!/usr/bin/perl

use strict;
use warnings;
use open qw/:std :utf8/;
use DBI;
use XML::Simple;

###################################
my $dictionary_name = 'LingvoUniversalRuEn_2.4.2';
#my $dictionary_name = 'LingvoUniversalEnRu_2.4.2';
my $dictionary_file = "../data/dic/ini/LingvoUniversalRE.xml";
#my $dictionary_file = "../data/dic/ini/LingvoUniversalER.xml";
my $clean = 0; # DROP TABLE source : 1 = yes, 0 = no

my $db_name = 'Dictionary';
my $host = 'localhost';
my $login = 'root';
my $password = '';
###################################

my $dbh = DBI->connect("DBI:mysql:$db_name:$host;mysql_local_infile=1", $login, $password, {RaiseError => 1, PrintError => 0}) || die "$DBI::err($DBI::errstr)\n";

$dbh->do('DROP TABLE IF EXISTS `source_lingvo`') if $clean;
$dbh->do('CREATE TABLE IF NOT EXISTS `source_lingvo` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `dictionary` char(64) DEFAULT NULL,
        `keyword` char(128) DEFAULT NULL,
        `definition` text,
        PRIMARY KEY (`id`),
        KEY `keyword` (`keyword`)
    )DEFAULT CHARSET=utf8'
);
my $load = $dbh->prepare(q/LOAD DATA LOCAl INFILE ? INTO TABLE `source_lingvo` CHARACTER SET UTF8 FIELDS TERMINATED BY '\r' LINES TERMINATED BY '\r\r'/);

my $xml = new XML::Simple (NoAttr=>1, RootName=>'stardict');
print "Data parsing...";
my $data = $xml->XMLin($dictionary_file);
print " ok\nData loading...";
open (OUT, ">", "tmp.file") || die;
for my $key (keys $data->{article}) {
    $data->{article}{$key}{definition} =~ s/^\s+//s;
    $data->{article}{$key}{definition} =~ s/\s+$//s;
    $data->{article}{$key}{definition} =~ s/\n +/\n/sg;
    
    print OUT (join("\r", '\N', $dictionary_name, $key, $data->{article}{$key}{definition}), "\r\r");
}
close OUT;
$load->execute('tmp.file');
unlink "tmp.file";

print "ok\n";
print "finished!\n";
