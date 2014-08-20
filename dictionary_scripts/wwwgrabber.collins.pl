#!/usr/bin/perl

use strict;
use warnings;

use utf8;

use DBI;
use LWP::UserAgent;
use URI::Encode qw(uri_encode uri_decode);
use Encode qw (encode decode);
use Time::HiRes qw (sleep);


###################################
my $infile = "/data/webprojects/docdic_data/collins.keywords.txt";

my $dictionary = 'Collins COBUILD English for Learners';
#my $dictionary = 'LingvoUniversal (En-Ru)';

my $version = 'http://www.collinsdictionary.com/dictionary/english-cobuild-learners (grab date: Aug2014) with keywords of ';
#my $version = 'www.lingvo-online.ru (grab date: Aug2014) with keywords of LingvoUniversal (En-Ru) 2008.11.14';

my $alias  = 'Lingvo';

my $source = 'ru';
#my $source = 'en';

my $target = 'en';
#my $target = 'ru';

my $dictionary_name = 'Universal+(Ru-En)';
#my $dictionary_name = 'LingvoUniversal+(En-Ru)';

my $url = 'http://www.lingvo-online.ru/ru/Search/Translate/FullLingvoArticle?dictionarySystemName=';
#&title=word_to_translate&random_hyyd20np=1'; #random_hyyastxy

my $sleep_time = 0.5;
###################################

###################################
my $db_name = 'wm_dict';
my $host = 'localhost';
my $login = 'root';
my $password = '';
my $clean = 0;
###################################

my $dbh = DBI->connect("DBI:mysql:$db_name:$host;mysql_local_infile=1", $login, $password, {RaiseError => 1, PrintError => 0, mysql_enable_utf8 => 1}) || die "$DBI::err($DBI::errstr)\n";

$dbh->do('DROP TABLE IF EXISTS `dic_lingvo_www`') if $clean;
$dbh->do('CREATE TABLE IF NOT EXISTS `dic_lingvo_www` (
            `article_id` int(11) NOT NULL AUTO_INCREMENT,
            `keyword` varchar(128) DEFAULT NULL,
            `article` longtext,
            `source` varchar(3) DEFAULT NULL,
            `target` varchar(3) DEFAULT NULL,
            `dictionary` varchar(128) DEFAULT NULL,
            `version` varchar(128) DEFAULT NULL,
            `alias` varchar(64) DEFAULT NULL,
            PRIMARY KEY (`article_id`),
            KEY `keyword` (`keyword`)
          ) ENGINE=MyISAM DEFAULT CHARSET=utf8'
);

my $select_max = $dbh->prepare(q/SELECT MAX(article_id) FROM `dic_lingvo_www`/);
my $select_basic = $dbh->prepare(q/SELECT COUNT(*) FROM `dic_lingvo_www` WHERE BINARY keyword = ?/);
my $load_basic = $dbh->prepare(q/INSERT INTO `dic_lingvo_www` (keyword, article, source, target, dictionary, version, alias) VALUES (?, ?, ?, ?, ?, ?, ?)/);

$select_max->execute();
my ($n) = $select_max->fetchrow_array();
$n++;

$url .= $dictionary_name.'&title=';

my @chars = ("0".."9", "a".."z");
my $rand_str = '&random_hyy'.join('', (map {$chars[rand @chars]} (1..5))).'=1';

my $ua = LWP::UserAgent->new();
$ua->agent("Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)");

open(IN, "<", $infile) || die;
while (my $word = <IN>) {
    chomp $word;
    next if $word =~ m/[><]/;
    $select_basic->execute($word);
    my ($in_table) = $select_basic->fetchrow_array();
    if($in_table) {
        print $word, "\n";
        next;
    }
    my $rqst = $url.uri_encode(decode("utf8", $word)).$rand_str;
    my $request = HTTP::Request->new(GET => $rqst);
    my $res = $ua->request($request);
    while ($res->{_rc} != 200) {
        print "sleep!\n";
        sleep 3;
        $res = $ua->request($request);
    }
    my $content = $res->{_content};
    
    if ($content !~ m/^\{"article"/) {
        die "ERROR:\$word\n";
    }
    next if $content =~ m/^\{"article".null\}/;
    $load_basic->execute($word, $content, $source, $target, $dictionary, $version, $alias);
    print $n++, '> ', $word, "\n";
    sleep $sleep_time;
}
close IN;

print "finished!\n";

