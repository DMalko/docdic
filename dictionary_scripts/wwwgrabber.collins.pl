#!/usr/bin/perl

use strict;
use warnings;

use utf8;

use DBI;
use LWP::UserAgent;
use URI::Encode qw(uri_encode uri_decode);
use Encode qw (encode decode);
use Time::HiRes qw (sleep);
use Mojo::DOM;


###################################
my $infile = "/data/webprojects/DocDic.Project/docdic_data/keywords/collins.keywords.txt";

my $dictionary = 'Collins COBUILD Advanced Learner&apos;s Dictionary 2006';

my $version = q#http://www.collinsdictionary.com/dictionary/english-cobuild-learners (grab date: Aug2014) with keywords of Collins COBUILD Advanced Learner's Dictionary 2006#;
my $alias  = 'Collins';
my $source = 'en';
my $target = 'en';


my $url = 'http://www.collinsdictionary.com/dictionary/english-cobuild-learners/';

my $sleep_time = 1;
###################################

###################################
my $db_name = 'wm_dict';
my $host = 'localhost';
my $login = 'root';
my $password = '';
my $clean = 0;
###################################

my $dbh = DBI->connect("DBI:mysql:$db_name:$host;mysql_local_infile=1", $login, $password, {RaiseError => 1, PrintError => 0, mysql_enable_utf8 => 1}) || die "$DBI::err($DBI::errstr)\n";

$dbh->do('DROP TABLE IF EXISTS `dic_collins_www`') if $clean;
$dbh->do('CREATE TABLE IF NOT EXISTS `dic_collins_www` (
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

my $select_max = $dbh->prepare(q/SELECT MAX(article_id) FROM `dic_collins_www`/);
my $select_basic = $dbh->prepare(q/SELECT COUNT(*) FROM `dic_collins_www` WHERE BINARY keyword = ?/);
my $load_basic = $dbh->prepare(q/INSERT INTO `dic_collins_www` (keyword, article, source, target, dictionary, version, alias) VALUES (?, ?, ?, ?, ?, ?, ?)/);

$select_max->execute();
my ($n) = $select_max->fetchrow_array();
$n++;

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
    my $rqst = $url.uri_encode($word);
    my $request = HTTP::Request->new(GET => $rqst);
    my $res = $ua->request($request);
    while ($res->{_rc} != 200) {
        print "sleep!\n";
        sleep 3;
        $res = $ua->request($request);
    }
    my $content = decode("utf8", $res->{_content});
    html_washer(\$content);
    $content =~ s/\s+/ /sg;
    
    unless ($content) {
        print "no entry: $word\n";
        next;
    }
    $load_basic->execute($word, $content, $source, $target, $dictionary, $version, $alias);
    print $n++, '> ', $word, "\n";
    sleep $sleep_time;
}
close IN;

print "finished!\n";

###################################################################################
sub html_washer {
    my $html = shift;
    
    my $dom = Mojo::DOM->new($$html);
    $$html = undef;
    for my $data ($dom->find('div[class="definition_content col main_bar"]')->each) {
        for my $garbage ($data->children('div[class="term-subsec"]')->each) {
            $garbage->remove;
        }
        for my $garbage ($data->children('script')->each) {
            $garbage->remove;
        }
        for my $garbage ($data->children('div[class="the_word"]')->each) {
            $garbage->remove;
        }
        $$html = $data->to_string;
        last;
    }
    
    return 1;
}

