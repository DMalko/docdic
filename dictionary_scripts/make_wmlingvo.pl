#!/usr/bin/perl

use strict;
use warnings;

use DBI;
use JSON::XS;
use Encode;
use File::Temp;

###################################
my $clean = 1; # DROP TABLE source : 1 = yes, 0 = no

# dictionary db
my $db_name_dic = 'Dictionary';
my $host_dic = 'localhost';
my $login_dic = 'root';
my $password_dic = '';
# wm db
my $db_name_wm = 'wm_dict';
my $host_wm = 'localhost';
my $login_wm = 'root';
my $password_wm = '';
###################################


my $dbh_dic = DBI->connect("DBI:mysql:$db_name_dic:$host_dic;mysql_local_infile=1", $login_dic, $password_dic, {RaiseError => 1, PrintError => 0, mysql_enable_utf8 => 1}) || die "$DBI::err($DBI::errstr)\n";
my $dbh_wm = DBI->connect("DBI:mysql:$db_name_wm:$host_wm;mysql_local_infile=1", $login_wm, $password_wm, {RaiseError => 1, PrintError => 0, mysql_enable_utf8 => 1}) || die "$DBI::err($DBI::errstr)\n";

$dbh_wm->do(q/DROP TABLE IF EXISTS `dict_lingvo`/) if $clean;
$dbh_wm->do(q/
    CREATE TABLE IF NOT EXISTS `dict_lingvo` (
    `kw_id` int(11) NOT NULL AUTO_INCREMENT,
    `keyword` varchar(128) DEFAULT NULL,
    `body` text,
    `source` char(2) DEFAULT NULL,
    `target` char(2) DEFAULT NULL,
    `dictionary` varchar(64) DEFAULT NULL,
    `like` int(11) NOT NULL DEFAULT '0',
    `error` int(11) NOT NULL DEFAULT '0',
    `created` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`kw_id`),
    KEY `keyword` (`keyword`,`source`)
  ) ENGINE=MyISAM DEFAULT CHARSET=utf8
/);

my $load = $dbh_wm->prepare(q/LOAD DATA LOCAl INFILE ? INTO TABLE `dict_lingvo` CHARACTER SET UTF8 FIELDS TERMINATED BY '\r' LINES TERMINATED BY '\r\r'/);
my $select_kw = $dbh_dic->prepare(q/SELECT keyword, definition, dictionary FROM source_lingvo ORDER BY id/);

my $tmp = File::Temp->new();
binmode($tmp, ":utf8");

my $card = {};
$select_kw->execute();
while(my ($kw, $trn, $dict) = $select_kw->fetchrow_array()) {
    my ($s, $t) = lang($dict);
    $trn =~ s/<dtrn>/<span class="lng_trnsl">/sg;
    $trn =~ s/<co>/<span class="lng_co">/sg;
    $trn =~ s/<abr>/<span class="lng_abr">/sg;
    $trn =~ s/<c>/<span class="lng_cc">/sg;
    $trn =~ s/<k>/<span class="lng_kw">/sg;
    $trn =~ s/<kref>/<span class="lng_kwref">/sg;
    $trn =~ s/<ex>/<span class="lng_exmpl">/sg;
    $trn =~ s/<tr>/<span class="lng_trnsc">/sg;
    $trn =~ s/<opt>/<span class="lng_opt">/sg;
    $trn =~ s/<\/(?:dtrn>|co?|abr|k(?:ref)?|ex|tr|opt)>/<\/span>/sg;
    $trn =~ s/<nu \/>//sg;
    $trn =~ s/\n/<br>/sg;
    
    $tmp->print(join("\r", '\N', $kw, $trn, $s, $t, $dict, 0, 0), "\r\r");
}
$tmp->close;
$load->execute($tmp);

print "...done\n";

### subs ###############################
sub lang {
    my $d = shift;
    return ('ru', 'en') if $d =~ m/RuEn/;
    return ('en', 'ru') if $d =~ m/EnRu/;
}

