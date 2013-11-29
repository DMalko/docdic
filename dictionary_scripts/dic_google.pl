#!/usr/bin/perl

use strict;
use warnings;
use DBI;
use JSON;
use Encode;
use File::Temp;

###################################
#my $dic_source_name = 'GoogleEnRu_Jul2013';
my $dic_source_name = 'GoogleRuEn_Jul2013';
my $sorce = 'ru';
my $target = 'en';
my $clean = 0; # DROP TABLE source : 1 = yes, 0 = no

my $db_name = 'Dictionary';
my $host = 'localhost';
my $login = 'root';
my $password = '';
###################################

my $dbh = DBI->connect("DBI:mysql:$db_name:$host;mysql_local_infile=1", $login, $password, {RaiseError => 1, PrintError => 0, mysql_enable_utf8 => 1}) || die "$DBI::err($DBI::errstr)\n";

$dbh->do('DROP TABLE IF EXISTS `dic_google_basic`') if $clean;
$dbh->do('CREATE TABLE IF NOT EXISTS `dic_google_basic` (
        `keyword_id` int(11) NOT NULL AUTO_INCREMENT,
        `keyword` char(128) DEFAULT NULL,
        `translation` char(128) DEFAULT NULL,
        `source` char(2) DEFAULT NULL,
        `target` char(2) DEFAULT NULL,
        `dictionary` char(64) DEFAULT NULL,
        PRIMARY KEY (`keyword_id`),
        KEY `keyword` (`keyword`)
    )DEFAULT CHARSET=utf8'
);

$dbh->do('DROP TABLE IF EXISTS `dic_google_trn`') if $clean;
$dbh->do('CREATE TABLE IF NOT EXISTS `dic_google_trn` (
        `trn_id` int(11) NOT NULL AUTO_INCREMENT,
        `keyword_id` int(11) DEFAULT NULL,
        `type` char(32) DEFAULT NULL,
        `translation` char(128) DEFAULT NULL,
        `score` float DEFAULT NULL,
        PRIMARY KEY (`trn_id`),
        KEY `keyword_id` (`keyword_id`),
        KEY `translation` (`translation`)
    )DEFAULT CHARSET=utf8'
);

$dbh->do('DROP TABLE IF EXISTS `dic_google_rtrn`') if $clean;
$dbh->do('CREATE TABLE IF NOT EXISTS `dic_google_rtrn` (
        `rtrn_id` int(11) NOT NULL AUTO_INCREMENT,
        `trn_id` int(11) DEFAULT NULL,
        `keyword_id` int(11) DEFAULT NULL,
        `rtranslation` char(128) DEFAULT NULL,
        PRIMARY KEY (`rtrn_id`),
        KEY `trn_id` (`trn_id`),
        KEY `keyword_id` (`keyword_id`),
        KEY `rtranslation` (`rtranslation`)
    )DEFAULT CHARSET=utf8'
);

my $load_basic = $dbh->prepare(q/LOAD DATA LOCAl INFILE ? INTO TABLE `dic_google_basic` CHARACTER SET UTF8 FIELDS TERMINATED BY '\r' LINES TERMINATED BY '\r\r'/);
my $load_trn = $dbh->prepare(q/LOAD DATA LOCAl INFILE ? INTO TABLE `dic_google_trn` CHARACTER SET UTF8 FIELDS TERMINATED BY '\r' LINES TERMINATED BY '\r\r'/);
my $load_rtrn = $dbh->prepare(q/LOAD DATA LOCAl INFILE ? INTO TABLE `dic_google_rtrn` CHARACTER SET UTF8 FIELDS TERMINATED BY '\r' LINES TERMINATED BY '\r\r'/);

my $query = $dbh->prepare(q/SELECT id, keyword, definition FROM source_google WHERE dictionary = ? ORDER BY id/);


my $keyword_id = ($dbh->selectrow_array(q/SELECT MAX(keyword_id) FROM dic_google_basic/))[0];
my $trn_id = ($dbh->selectrow_array(q/SELECT MAX(trn_id) FROM dic_google_trn/))[0];
my $rtrn_id = ($dbh->selectrow_array(q/SELECT MAX(rtrn_id) FROM dic_google_rtrn/))[0];

$keyword_id ||= 0;
$trn_id ||= 0;
$rtrn_id ||= 0;

my $tmp1 = File::Temp->new();
my $tmp2 = File::Temp->new();
my $tmp3 = File::Temp->new();
binmode($tmp1, ":encoding(utf8)");
binmode($tmp2, ":encoding(utf8)");
binmode($tmp3, ":encoding(utf8)");

my $json = JSON->new();
$json->allow_nonref();
open (BF, ">encoding(utf8)", "$dic_source_name.broken_phrases") || die;
$query->execute($dic_source_name);
my $broken_phrases = 0;
while (my ($id, $keyword, $data) = $query->fetchrow_array()) {
    print  $id, "\n";
    
    $data =~ s/\[\]/\[null\]/sg;
    $data =~ s/,(?=,)/,null/sg;
    $data =~ s/(?<=[\[\],])""(?=[\[\],])/"null"/sg;
    $data =~ s/(?<=[^\[\],])"(?=[^\[\],])/`/sg;
    $data =~ s/(?<=[^\[\],])""/`"/sg;
    $data =~ s/""(?=[^\[\],])/"`/sg;
    
    my $perl_scalar = $json->decode($data);
    my $basic = $perl_scalar->[0];
    if (@$basic > 1 || $basic->[0][1] ne $keyword) {
        print BF "$keyword\n";
        $broken_phrases++;
        next;
    }
    my $keyword_trn = $basic->[0][0];
    my $meanings = $perl_scalar->[1];
    
    $tmp1->print(join("\r", ++$keyword_id, $keyword, $keyword_trn, $sorce, $target, $dic_source_name), "\r\r");
    
    for my $meaning (@$meanings) {
        my $part_of_speech = $meaning->[0];
        #my $translations = $meaning->[1];
        my $usages = $meaning->[2];
        my %trn = ();
        for my $usage (@$usages){
            my $trn = $usage->[0];
            my $trn_score = $usage->[3];
            $trn_score ||= '\N';
            
            next if exists $trn{$trn}; # filter for repeats
            $tmp2->print(join("\r", ++$trn_id, $keyword_id, $part_of_speech, $trn, $trn_score), "\r\r");
            $trn{$trn} = 1;
            
            my $rtrns = $usage->[1];
            for my $rtrn (@$rtrns) {
                
                $tmp3->print(join("\r", ++$rtrn_id, $trn_id, $keyword_id, $rtrn), "\r\r");
                
            }
        }
    }
}
close BF;
$tmp1->close();
$tmp2->close();
$tmp3->close();
$load_basic->execute($tmp1);
$load_trn->execute($tmp2);
$load_rtrn->execute($tmp3);

print "broken phrases: $broken_phrases\n";
print "finished!\n";



