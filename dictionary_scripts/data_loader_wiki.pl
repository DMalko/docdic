#! /usr/bin/perl

use warnings;
use strict;
use Data::Dumper;

use MediaWiki::DumpFile::Compat;
use Encode qw(encode);
use DBI;

############################################################
my $wikifile = '../enwiktionary-latest-pages-articles.xml';
my $output = '../wiktionary.tags.dump';
my $language = 'English';
my $clean = 1; # DROP TABLE `source_wiktionary` : 1 = yes, 0 = no

my $db_name = 'Dictionary';
my $host = 'localhost';
my $login = 'root';
my $password = '';
############################################################

my $dbh = DBI->connect("DBI:mysql:$db_name:$host;mysql_local_infile=1", $login, $password, {RaiseError => 1, PrintError => 0}) || die "$DBI::err($DBI::errstr)\n";

$dbh->do('DROP TABLE IF EXISTS `source_wiktionary`') if $clean;
$dbh->do('CREATE TABLE IF NOT EXISTS `source_wiktionary` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `dictionary` char(64) DEFAULT NULL,
        `keyword` char(128) DEFAULT NULL,
        `definition` text CHARSET utf8mb4,
        PRIMARY KEY (`id`),
        KEY `keyword` (`keyword`)
    )DEFAULT CHARSET=utf8'
);
my $load = $dbh->prepare(q/LOAD DATA LOCAl INFILE ? INTO TABLE `source_wiktionary` CHARACTER SET utf8mb4 FIELDS TERMINATED BY '\r' LINES TERMINATED BY '\r\r'/);


my $pmwd = Parse::MediaWikiDump->new();
my $pages = $pmwd->pages($wikifile);

my %fields = ();
open(OUT, '>', 'tmp.file') || die "$!\n";
while(defined(my $page = $pages->next)) {  
    my $title = encode('utf8', $page->title);
    my $text = encode('utf8', ${$page->text});
    if($text =~ m/^(?:[^\n]*\n){0,1}[^\n]*==(\w+)==/si && $1 eq $language) {
        while($text =~ m/=+[a-z]+=+/sgi){
            $fields{$&}++;
        }
        print OUT join("\r", '\N', 'WiktionaryEnEn_Jule2013', $title, $text), "\r\r";
        print $title, "\n";
    }    
}
close OUT;

open(OUT, '>', $output) || die "$!\n";
for my $key (sort {$fields{$b} <=> $fields{$a}} keys %fields){
    print OUT join("\t", $key, $fields{$key}), "\n";
}
close OUT;

$load->execute('tmp.file');
#unlink 'tmp.file';

print "finished!\n";
