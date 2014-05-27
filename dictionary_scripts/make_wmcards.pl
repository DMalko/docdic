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

# the ordered list of speech parts
my $sp = {
    en => [qw{noun pronoun adjective verb adverb preposition conjunction interjection article abbreviation phrase suffix prefix}],
    
};

my $dbh_dic = DBI->connect("DBI:mysql:$db_name_dic:$host_dic;mysql_local_infile=1", $login_dic, $password_dic, {RaiseError => 1, PrintError => 0, mysql_enable_utf8 => 1}) || die "$DBI::err($DBI::errstr)\n";
my $dbh_wm = DBI->connect("DBI:mysql:$db_name_wm:$host_wm;mysql_local_infile=1", $login_wm, $password_wm, {RaiseError => 1, PrintError => 0, mysql_enable_utf8 => 1}) || die "$DBI::err($DBI::errstr)\n";

$dbh_wm->do('DROP TABLE IF EXISTS `card`') if $clean;
$dbh_wm->do(q/
    CREATE TABLE IF NOT EXISTS `card` (
    `card_id` int(11) NOT NULL AUTO_INCREMENT,
    `keyword` varchar(128) DEFAULT NULL,
    `body` text,
    `source` char(2) DEFAULT NULL,
    `target` char(2) DEFAULT NULL,
    `dictionary` varchar(64) DEFAULT NULL,
    `author_uid` int(11) DEFAULT NULL,
    `like` int(11) NOT NULL DEFAULT '0',
    `error` int(11) NOT NULL DEFAULT '0',
    `created` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`card_id`),
    KEY `keyword` (`keyword`,`source`),
    KEY `author_uid` (`author_uid`)
  ) ENGINE=MyISAM DEFAULT CHARSET=utf8
/);

$dbh_dic->do('DROP TABLE IF EXISTS `tmp_google`') if $clean;
$dbh_dic->do(q/CREATE TABLE IF NOT EXISTS `tmp_google` (
  `trn_id` int(11) NOT NULL,
  `keyword_id` int(11) DEFAULT NULL,
  `type` char(32) DEFAULT NULL,
  `translation` char(128) DEFAULT NULL,
  `score` float DEFAULT NULL,
  `keyword` varchar(128) DEFAULT NULL,
  `record_num` int(3) DEFAULT NULL,
  `transcription` char(128) DEFAULT NULL,
  KEY (`trn_id`),
  KEY `keyword` (`keyword`),
  KEY `keyword_id` (`keyword_id`),
  KEY `translation` (`translation`)
) DEFAULT CHARSET=utf8
SELECT t3.*, keyword, record_num, transcription
FROM dic_google_basic AS t1 INNER JOIN dic_lingvo_basic AS t2 USING(keyword)
INNER JOIN dic_google_trn AS t3 ON t1.keyword_id = t3.keyword_id
INNER JOIN dic_lingvo_group AS t4 ON t2.keyword_id = t4.keyword_id
WHERE keyword IS NOT NULL AND t4.translation REGEXP t3.translation
GROUP BY trn_id, record_num 
/);
$dbh_dic->do(q/
INSERT INTO tmp_google
SELECT t2.*, t1.keyword, 0 AS record_num, transcription
FROM dic_google_basic AS t1 INNER JOIN dic_google_trn AS t2 USING(keyword_id)
LEFT JOIN word_rank_gutenberg AS t3 ON t1.keyword = t3.word
LEFT JOIN word_rank_ccae AS t4 ON t1.keyword = t4.word
LEFT JOIN tmp_google AS t5 ON t1.keyword = t5.keyword
WHERE t1.keyword IS NOT NULL AND (t3.word IS NOT NULL OR t4.word IS NOT NULL) AND
t5.keyword IS NULL
GROUP BY trn_id
/);

my $load = $dbh_wm->prepare(q/LOAD DATA LOCAl INFILE ? INTO TABLE `card` CHARACTER SET UTF8 FIELDS TERMINATED BY '\r' LINES TERMINATED BY '\r\r'/);

my $select_kw = $dbh_dic->prepare(q/SELECT t1.* FROM dic_google_basic AS t1 INNER JOIN tmp_google AS t2 USING(keyword_id) GROUP BY keyword_id ORDER BY keyword_id/);
my $select_trn_num = $dbh_dic->prepare(q/SELECT DISTINCT record_num FROM tmp_google WHERE keyword_id = ? ORDER BY record_num/);
my $select_trn = $dbh_dic->prepare(q/SELECT trn_id, type, translation, score FROM tmp_google WHERE keyword_id = ? AND record_num = ? ORDER BY keyword_id, record_num/);
my $select_tscr = $dbh_dic->prepare(q/SELECT DISTINCT transcription FROM tmp_google WHERE keyword_id = ? AND record_num = ? ORDER BY trn_id/);
my $select_rtrn = $dbh_dic->prepare(q/SELECT rtranslation FROM dic_google_rtrn WHERE trn_id = ? ORDER BY rtrn_id/);

my $select_wf = $dbh_dic->prepare(q/SELECT wordform, also_use FROM dic_collins_basic INNER JOIN dic_collins_form USING(keyword_id) WHERE keyword = ? ORDER BY form_id/);

my $tmp = File::Temp->new();
binmode($tmp, ":utf8");

my $card = {};
$select_kw->execute();
while(my ($kw_id, $kw, $trn, $s, $t) = $select_kw->fetchrow_array()) {
    my @card = ();
    $card[0] = $kw; # keyword
    $card[1] = [];  # wordforms
    $card[2] = [];  # alsouse's
    $card[3] = '';  # comment
        
    $select_wf->execute($kw);
    while(my ($wordform, $also_use) = $select_wf->fetchrow_array()) {
        $also_use ? push(@{$card[2]}, [$wordform, '']) : push(@{$card[1]}, [$wordform, '']); # [wordform, type]
    }
    
    my @definitions = ();
    $select_trn_num->execute($kw_id);
    while(my ($record_num) = $select_trn_num->fetchrow_array()) {
        my %speechparts = ();
        $select_trn->execute($kw_id, $record_num);
        while(my ($trn_id, $type, $tran, $score) = $select_trn->fetchrow_array()) {
            my @syn = ();
            $select_rtrn->execute($trn_id);
            while(my ($rtran) = $select_rtrn->fetchrow_array()) {
                push @syn, $rtran;
            }
            die "ERROR: wrong speechpart definition - $kw\n" unless $type;
            push @{$speechparts{$type}}, [$score, $tran, \@syn]; # [rate, trans, syn]
            
        }
        # speech parts sorting
        my @speechparts = ();
        for my $sp (@{$sp->{en}}) {
            if(exists $speechparts{$sp}) {
               push @speechparts, [$sp, $speechparts{$sp}]; # [speechpart, [records]]
               delete $speechparts{$sp};
            }
        }
        for my $sp (keys %speechparts) {
            push @speechparts, [$sp, $speechparts{$sp}]; # [speechpart, [records]]
            delete $speechparts{$sp};
        }
        
        my @pronunciations = ();
        $select_tscr->execute($kw_id, $record_num);
        while(my ($tscr) = $select_tscr->fetchrow_array()) {
            push @pronunciations, [$tscr, $kw, '']; # [transcription, sound, note]
        }
        $definitions[0] = \@pronunciations; # pronunciations
        $definitions[1] = \@speechparts; # speechparts
    }
    die "ERROR: no speechpart definitions - $kw\n" unless @definitions;
    $card[4] = \@definitions;
    
    my $json = Encode::decode('utf8', encode_json \@card);
    $tmp->print(join("\r", '\N', $kw, $json, $s, $t, 'wmdict', '\N', 0, 0), "\r\r");
}
$tmp->close;
$load->execute($tmp);
$dbh_dic->do(q/DROP TABLE `tmp_google`/);

print "...done\n";

