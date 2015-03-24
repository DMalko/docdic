#!/usr/bin/perl

use strict;
use warnings;

use utf8;

use DBI;
use LWP::UserAgent;
use Mojo::DOM;
use URI::Encode qw(uri_encode uri_decode);
use Encode qw (encode decode);
use Time::HiRes qw (sleep);
use JSON;
use MIME::Base64;

###################################
my $infile = "/data/webprojects/DocDic.Project/docdic_data/keywords/lingvo_ru-en.keywords.txt";
#my $infile = "/data/webprojects/DocDic.Project/docdic_data/keywords/lingvo_en-ru.keywords.txt";

my $dictionary = 'Universal (Ru-En)';
#my $dictionary = 'LingvoUniversal (En-Ru)';

my $version = 'www.lingvo-online.ru (grab date: Aug2014) keyword of Universal (Ru-En) 2004';
#my $version = 'www.lingvo-online.ru (grab date: Aug2014) keyword of LingvoUniversal (En-Ru) 2008';

my $alias  = 'Lingvo';

my $source = 'ru';
#my $source = 'en';

my $target = 'en';
#my $target = 'ru';

my $dictionary_name = 'Universal+(Ru-En)';
#my $dictionary_name = 'LingvoUniversal+(En-Ru)';

my $domain = 'http://www.lingvo-online.ru';
my $url = '/ru/Search/Translate/FullLingvoArticle?dictionarySystemName=';
#&title=word_to_translate&random_hyyd20np=1'; #random_hyyastxy

my $sound_dir = '.';

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

my @chars = ("0".."9", "a".."z");
$url = $domain.$url.$dictionary_name.'&title=';

my $ua = LWP::UserAgent->new();
$ua->agent("Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)");

open(IN, "<", $infile) || die;
while (my $word = <IN>) {
    chomp $word;
    next if $word =~ m/[><]/ || is_stored($word);
    
    my $rand_str = '&random_hyy'.join('', (map {$chars[rand @chars]} (1..5))).'=1';
    my $rqst = $url.uri_encode(decode("utf8", $word)).$rand_str;
    my $content = get_url($rqst);
    my $json = decode_json($content);
    my $article = $json->{article};
    next if (!$article) || $article eq 'null';
    $article =~ s/\s+/ /sgi;
    
    for my $url_link (find_sound_links(\$article)) {
        next unless $url_link =~ m/FileName=([^&]+).*DictionaryName=(.+)/;
        my $file_name = decode_base64($1);
        my $dict_name = uri_decode($2);
        my $file_path = '/'.$dict_name.'/'.substr($file_name,0,1).'/'.$file_name;
        make_path($sound_dir, $file_path);
        get_url($domain.$url_link, ':content_file' => $sound_dir.$file_path)
    }
    
    $load_basic->execute($word, $article, $source, $target, $dictionary, $version, $alias);
    print $n++, '> ', $word, "\n";
    sleep $sleep_time;
}
close IN;

print "finished!\n";

############################################################################################
sub is_stored {
    my $word = shift;
    
    $select_basic->execute($word);
    my ($in_table) = $select_basic->fetchrow_array();
    if($in_table) {
        print 'IN STOCK: ', $word, "\n";
        return 1;
    }
    
    return;
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
        my $status = $res->status_line;
        print STDERR $status, "\n";
        #return if $status =~ m/404 /;
        sleep 3;
        $res = $ua->get($request);
        die "ERROR: request fault ($request)\n" if ++$n > 3;
    }
    
    return $res->decoded_content;
}

sub find_sound_links {
    my $html = shift;
    
    my @links = ();
    my $dom = Mojo::DOM->new($$html);
    for my $sound ($dom->find('span[class="l-article__sound"] span[class="jp-jplayer"]')->each) {
        my $link = $sound->attr('data-flash-url');
        push @links, $link if $link;
    }
    return @links;
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