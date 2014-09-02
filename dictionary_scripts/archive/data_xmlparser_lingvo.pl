#!/usr/bin/perl

use strict;
use warnings;
use open qw/:std :utf8/;
use DBI;
use XML::Simple;
use utf8;

###################################
#my $dictionary_name = 'Lingvo Universal (EnRu) (к версии ABBYY Lingvo x3) от 2008.11.14';
my $dictionary_name = 'Universal (Ru-En) (к версии ABBYY Lingvo x3) от 2008.11.14';
#my $source = 'en';
my $source = 'ru';
#my $target = 'ru';
my $target = 'en';
#my $dictionary_file = "/data/webprojects/docdic_data/xml/LingvoUniversalEnRu.xml";
my $dictionary_file = "/data/webprojects/docdic_data/xml/UniversalRuEn.xml";
my $clean = 0; # DROP TABLE source : 1 = yes, 0 = no

my $db_name = 'wm_dict';
my $host = 'localhost';
my $login = 'root';
my $password = '';
###################################

my $dbh = DBI->connect("DBI:mysql:$db_name:$host;mysql_local_infile=1", $login, $password, {RaiseError => 1, PrintError => 0}) || die "$DBI::err($DBI::errstr)\n";

$dbh->do('DROP TABLE IF EXISTS `source_lingvo`') if $clean;
$dbh->do('CREATE TABLE IF NOT EXISTS `source_lingvo` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `dictionary` char(64) DEFAULT NULL,
        `source` char(3) DEFAULT NULL,
        `target` char(3) DEFAULT NULL,
        `keyword` char(128) DEFAULT NULL,
        `definition` text,
        PRIMARY KEY (`id`),
        KEY `keyword` (`keyword`)
    )ENGINE=MyISAM DEFAULT CHARSET=utf8'
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
    
    my $html = makeHTML($data->{article}{$key}{definition});
    
    print OUT (join("\r", '\N', $dictionary_name, $source, $target, $key, $html), "\r\r");
}
close OUT;
$load->execute('tmp.file');
unlink "tmp.file";

print "ok\n";
print "finished!\n";

sub makeHTML {
    my $data = shift;
    
    my %tags = (
        abr  => 'span class="lng_abbrev"',
        dtrn => 'span class="lng_trnansl"',
        co   => 'span class="lng_co"',
        k    => 'span class="lng_kword"',
        ex   => 'span class="lng_examp"',
        kref => 'span class="lng_refer"',
        tr   => 'span class="lng_transc"',
        c    => 'span class="lng_colored"',
        opt  => 'span class="lng_opt"',
    );
    
    $data =~ s/<nu \/>//sg;
    $data =~ s/<iref>.*?<\/iref>//sg;
    $data =~ s/<tr>/<tr>\[/sg;
    $data =~ s/<\/tr>/<\/tr>\]/sg;
    
    $data =~ s/<\/(?:abr|dtrn|co|k|ex|kref|tr|c|opt|)>//sg;
    $data =~ s/<(abr|dtrn|co|k|ex|kref|tr|c|opt|)>/<$tags{$1}>/sg;
    
    $data =~ s/^[0-9a-z]+\).*/$&/i;
    $data =~ s/\n/<br>/sg;
}