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

$dbh_wm->do(q/DROP TABLE IF EXISTS `dict_collins`/) if $clean;
$dbh_wm->do(q/
    CREATE TABLE IF NOT EXISTS `dict_collins` (
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

my $load = $dbh_wm->prepare(q/LOAD DATA LOCAl INFILE ? INTO TABLE `dict_collins` CHARACTER SET UTF8 FIELDS TERMINATED BY '\r' LINES TERMINATED BY '\r\r'/);
my $select_kw = $dbh_dic->prepare(q/SELECT keyword, body, dictionary FROM dic_collins_basic ORDER BY keyword_id/);

my $tmp = File::Temp->new();
binmode($tmp, ":utf8");

my $card = {};
$select_kw->execute();
while(my ($kw, $trn, $dict) = $select_kw->fetchrow_array()) {
    my ($s, $t) = lang($dict);
    
    my $stars = '';
    my $fline = '';
    if($trn =~ s/^(\x{2605}+)<BR>//i) {
        $stars = '<SPAN class="collins-stars">'.$1.'</SPAN><BR>';
    }
    if($trn =~ s/^(.+?)<BR>//i) {
        $fline = '<SPAN class="collins-fline">'.$1.'</SPAN><BR>';
    }
    $trn = $stars.$fline.$trn;
    $tmp->print(join("\r", '\N', $kw, $trn, $s, $t, $dict, 0, 0), "\r\r");
}
$tmp->close;
$load->execute($tmp);

print "...done\n";

### subs ###############################
sub lang {
    return ('en', 'en');
}

