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
use HTML::Entities qw (decode_entities);


###################################
my $dictionary = 'Collins COBUILD Advanced Learner&apos;s Dictionary (2014)';

my $version = 'Collins COBUILD Advanced Learner&apos;s Dictionary (online Aug2014)';
my $alias  = 'Collins';
my $source = 'en';
my $target = 'en';

my $sound_dir = '.';

my $domain = 'http://www.collinsdictionary.com';
my $url_alphabet = '/dictionary/english-cobuild-learners';

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

$dbh->do('DROP TABLE IF EXISTS `dic_collins_sound`') if $clean;
$dbh->do('CREATE TABLE IF NOT EXISTS `dic_collins_sound` (
            `sound_id` int(11) NOT NULL AUTO_INCREMENT,
            `keyword` varchar(128) DEFAULT NULL,
            `path` text,
            PRIMARY KEY (`sound_id`),
            KEY `keyword` (`keyword`)
          ) ENGINE=MyISAM DEFAULT CHARSET=utf8'
);

my $select_max = $dbh->prepare(q/SELECT MAX(sound_id) FROM `dic_collins_sound`/);
my $select_basic = $dbh->prepare(q/SELECT COUNT(*) FROM `dic_collins_sound` WHERE BINARY keyword = ? AND path = ?/);
my $select_article = $dbh->prepare(q/SELECT keyword, article FROM `source_collins_www`/);
my $load_basic = $dbh->prepare(q/INSERT INTO `dic_collins_sound` (keyword, path) VALUES (?, ?)/);

$select_max->execute();
my ($n) = $select_max->fetchrow_array();
$n++;

$sound_dir =~ s/\/$//;

my $ua = LWP::UserAgent->new();
$ua->agent("Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)");

$select_article->execute();
while( my ($keyword, $content) = $select_article->fetchrow_array()) {
    for my $url_link (find_sound_links(\$content)) {
        next if is_stored($keyword, $url_link);
        make_path($sound_dir, $url_link);
        get_url($domain.$url_link, ':content_file' => $sound_dir.$url_link);
        $load_basic->execute($keyword, $url_link);
        print $n++, '> ', $keyword, ' : ', $url_link, "\n";
    }
}

print "finished!\n";

###################################################################################
sub is_stored {
    my $word = shift;
    my $link = shift;
    
    $select_basic->execute($word, $link);
    my ($in_table) = $select_basic->fetchrow_array();
    if($in_table) {
        print 'IN STOCK: ', $word, ' : ', $link, "\n";
        return 1;
    }
    
    return;
}

sub make_path {
    my $root = shift;
    my $path = shift;
    
    while ($path =~ m/([^\/]+)\//g) {
        $root .= '/' if $root !~ m/\/$/;
        $root .= $1;
        mkdir $root unless -e $root;
    }
    
    return 1;
}

sub find_sound_links {
    my $html = shift;
    
    my @links = ();
    my $dom = Mojo::DOM->new($$html);
    for my $sound ($dom->find('img[class="sound"]')->each) {
        my $link = $sound->attr('onclick');
        if ($link =~ m/'(\/sounds[^']+mp3)'/i) {
            push @links, $1;
        }
    }
    return @links;
}

sub get_url {
    my $request = shift;
    my @options = @_;
    
    sleep $sleep_time;
    
    #my $request = HTTP::Request->new(GET => shift);
    #my $res = $ua->request($request);
    my $res = $ua->get($request, @options);
    my $n = 0;
    while (!$res->is_success) {
        print STDERR $res->status_line, "\n";
        sleep 3;
        $res = $ua->get($request);
        die "ERROR: request fault ($request)\n" if ++$n > 3;
    }
    
    return $res->decoded_content;
}
