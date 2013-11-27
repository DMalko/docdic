#!/usr/bin/perl

use strict;
use warnings;

use utf8;
use Roman;

#!/usr/bin/perl

use strict;
use warnings;
use DBI;
use JSON;
use Encode;
use File::Temp;

###################################
#my $dic_source_name = 'LingvoUniversalEnRu_2.4.2';
my $dic_source_name = 'LingvoUniversalRuEn_2.4.2';
my $sorce = 'ru';
my $target = 'en';
my $clean = 1; # DROP TABLE source : 1 = yes, 0 = no

my $db_name = 'Dictionary';
my $host = 'localhost';
my $login = 'root';
my $password = '';
###################################

my $dbh = DBI->connect("DBI:mysql:$db_name:$host;mysql_local_infile=1", $login, $password, {RaiseError => 1, PrintError => 0, mysql_enable_utf8 => 1}) || die "$DBI::err($DBI::errstr)\n";

$dbh->do('DROP TABLE IF EXISTS `dic_lingvo_basic`') if $clean;
$dbh->do('CREATE TABLE IF NOT EXISTS `dic_lingvo_basic` (
            `keyword_id` int(11) NOT NULL AUTO_INCREMENT,
            `keyword` char(128) DEFAULT NULL,
            `source` char(2) DEFAULT NULL,
            `target` char(2) DEFAULT NULL,
            `dictionary` char(64) DEFAULT NULL,
            PRIMARY KEY (`keyword_id`),
            KEY `keyword` (`keyword`)
          ) DEFAULT CHARSET=utf8'
);

$dbh->do('DROP TABLE IF EXISTS `dic_lingvo_col`') if $clean;
$dbh->do('CREATE TABLE IF NOT EXISTS `dic_lingvo_col` (
            `col_id` int(11) NOT NULL AUTO_INCREMENT,
            `group_id` int(11) DEFAULT NULL,
            `num` int(11) DEFAULT NULL,
            `collocation` char(128) DEFAULT NULL,
            PRIMARY KEY (`col_id`),
            KEY `group_id` (`group_id`),
            KEY `collocation` (`collocation`)
          ) DEFAULT CHARSET=utf8'
);

$dbh->do('DROP TABLE IF EXISTS `dic_lingvo_ex`') if $clean;
$dbh->do('CREATE TABLE IF NOT EXISTS `dic_lingvo_ex` (
            `ex_id` int(11) NOT NULL AUTO_INCREMENT,
            `group_id` int(11) DEFAULT NULL,
            `example` char(128) DEFAULT NULL,
            PRIMARY KEY (`ex_id`),
            KEY `group_id` (`group_id`)
          ) DEFAULT CHARSET=utf8'
);

$dbh->do('DROP TABLE IF EXISTS `dic_lingvo_group`') if $clean;
$dbh->do('CREATE TABLE IF NOT EXISTS `dic_lingvo_group` (
            `group_id` int(11) NOT NULL AUTO_INCREMENT,
            `keyword_id` int(11) DEFAULT NULL,
            `level` int(11) DEFAULT NULL,
            `number` char(3) DEFAULT NULL,
            PRIMARY KEY (`group_id`),
            KEY `keyword_id` (`keyword_id`)
          )  DEFAULT CHARSET=utf8'
);

$dbh->do('DROP TABLE IF EXISTS `dic_lingvo_syn`') if $clean;
$dbh->do('CREATE TABLE IF NOT EXISTS `dic_lingvo_syn` (
            `syn_id` int(11) NOT NULL AUTO_INCREMENT,
            `group_id` int(11) DEFAULT NULL,
            `synonym` char(128) DEFAULT NULL,
            PRIMARY KEY (`syn_id`),
            KEY `group_id` (`group_id`),
            KEY `synonym` (`synonym`)
          ) DEFAULT CHARSET=utf8'
);

$dbh->do('DROP TABLE IF EXISTS `dic_lingvo_trn`') if $clean;
$dbh->do('CREATE TABLE IF NOT EXISTS `dic_lingvo_trn` (
            `trn_id` int(11) NOT NULL AUTO_INCREMENT,
            `keyword_id` int(11) DEFAULT NULL,
            `group_id` int(11) DEFAULT NULL,
            `translation` char(128) DEFAULT NULL,
            PRIMARY KEY (`trn_id`),
            KEY `keyword_id` (`keyword_id`),
            KEY `group_id` (`group_id`),
            KEY `translation` (`translation`)
          ) DEFAULT CHARSET=utf8'
);

$dbh->do('DROP TABLE IF EXISTS `dic_lingvo_trp`') if $clean;
$dbh->do('CREATE TABLE IF NOT EXISTS `dic_lingvo_trp` (
            `trp_id` int(11) NOT NULL AUTO_INCREMENT,
            `group_id` int(11) DEFAULT NULL,
            `transcription` char(128) DEFAULT NULL,
            PRIMARY KEY (`trp_id`),
            KEY `group_id` (`group_id`)
          ) DEFAULT CHARSET=utf8'
);

my $load_basic = $dbh->prepare(q/LOAD DATA LOCAl INFILE ? INTO TABLE `dic_lingvo_basic` CHARACTER SET UTF8 FIELDS TERMINATED BY '\r' LINES TERMINATED BY '\r\r'/);
my $load_col = $dbh->prepare(q/LOAD DATA LOCAl INFILE ? INTO TABLE `dic_lingvo_col` CHARACTER SET UTF8 FIELDS TERMINATED BY '\r' LINES TERMINATED BY '\r\r'/);
my $load_ex = $dbh->prepare(q/LOAD DATA LOCAl INFILE ? INTO TABLE `dic_lingvo_ex` CHARACTER SET UTF8 FIELDS TERMINATED BY '\r' LINES TERMINATED BY '\r\r'/);
my $load_group = $dbh->prepare(q/LOAD DATA LOCAl INFILE ? INTO TABLE `dic_lingvo_group` CHARACTER SET UTF8 FIELDS TERMINATED BY '\r' LINES TERMINATED BY '\r\r'/);
my $load_syn = $dbh->prepare(q/LOAD DATA LOCAl INFILE ? INTO TABLE `dic_lingvo_syn` CHARACTER SET UTF8 FIELDS TERMINATED BY '\r' LINES TERMINATED BY '\r\r'/);
my $load_trn = $dbh->prepare(q/LOAD DATA LOCAl INFILE ? INTO TABLE `dic_lingvo_trn` CHARACTER SET UTF8 FIELDS TERMINATED BY '\r' LINES TERMINATED BY '\r\r'/);
my $load_trp = $dbh->prepare(q/LOAD DATA LOCAl INFILE ? INTO TABLE `dic_lingvo_trp` CHARACTER SET UTF8 FIELDS TERMINATED BY '\r' LINES TERMINATED BY '\r\r'/);

my $query = $dbh->prepare(q/SELECT id, keyword, definition FROM source_lingvo WHERE dictionary = ? ORDER BY id/);


my $keyword_id = ($dbh->selectrow_array(q/SELECT MAX(keyword_id) FROM dic_lingvo_basic/))[0];
my $col_id = ($dbh->selectrow_array(q/SELECT MAX(col_id) FROM dic_lingvo_col/))[0];
my $ex_id = ($dbh->selectrow_array(q/SELECT MAX(ex_id) FROM dic_lingvo_ex/))[0];
my $group_id = ($dbh->selectrow_array(q/SELECT MAX(group_id) FROM dic_lingvo_group/))[0];
my $syn_id = ($dbh->selectrow_array(q/SELECT MAX(syn_id) FROM dic_lingvo_syn/))[0];
my $trn_id = ($dbh->selectrow_array(q/SELECT MAX(trn_id) FROM dic_lingvo_trn/))[0];
my $trp_id = ($dbh->selectrow_array(q/SELECT MAX(trp_id) FROM dic_lingvo_trp/))[0];

$keyword_id ||= 0;
$col_id ||= 0;
$ex_id ||= 0;
$group_id ||= 0;
$syn_id ||= 0;
$trn_id ||= 0;
$trp_id ||= 0;


my $tmp1 = File::Temp->new();
my $tmp2 = File::Temp->new();
my $tmp3 = File::Temp->new();
binmode($tmp1, ":encoding(utf8)");
binmode($tmp2, ":encoding(utf8)");
binmode($tmp3, ":encoding(utf8)");

my %hash = ();
open(LOG, ">log.txt") || die;
$query->execute($dic_source_name);
while (my ($id, $keyword, $data) = $query->fetchrow_array()) {
    print  $id, "\n";
    
    $data =~ s/<b>1\.<\/b> *([^\n]+)//sg;
    $hash{$1}++ if $1;
}
map {print LOG $_, "\t", $hash{$_}, "\n"} keys %hash;


__END__
my $sss = '<abr><i><c><co>сущ.</co></c></i></abr>';

my $arabic = 15;
my $roman = 'IX';
$roman = roman($arabic);                        # convert to roman numerals
$arabic = arabic($roman) if isroman($roman);    # convert from roman numerals

$sss =~ m/.*(<(.*?)>.*(<\/\2>))/;
my $ss = $&;
my $ee = $1;
my $gg = $2;

1;