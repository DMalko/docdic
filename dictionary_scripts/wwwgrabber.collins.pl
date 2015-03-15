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

$sound_dir =~ s/\/$//;

my $ua = LWP::UserAgent->new();
$ua->agent("Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)");

my $content = get_url($domain.$url_alphabet);
#$content = decode("utf8", $content);

my $dom = Mojo::DOM->new($content);
for my $word_set_link ($dom->find('div[class="alphabet_wrapper alphabets"] a')->each) {
    my $link = $domain.$word_set_link->attr('href');
    print $link , "\n";

    my $content = get_url($link);
    #$content = decode("utf8", $content);
    my $dom_linkset = Mojo::DOM->new($content);
    for my $word_link ($dom_linkset->find('div[class="main_bar col lists"] div[class="col"] a')->each) {
        my $secont_level_link = $domain.$word_link->attr('href');
        my $word = $word_link->content;
        
        my $content = get_url($secont_level_link);
        #$content = decode("utf8", $content);
        
        my $dom_linkset2 = Mojo::DOM->new($content);
        if ($dom_linkset2->find('div[class="definition_content col main_bar"]')->each) {
            next if is_stored($word);
            
            for my $url_link (find_sound_links(\$content)) {
                next if -e $sound_dir.$url_link;
                make_path($sound_dir, $url_link);
                get_url($domain.$url_link, ':content_file' => $sound_dir.$url_link);
            }
            write_to_db($word, \$content);
        } else {
            for my $word_link2 ($dom_linkset2->find('div[class="main_bar col lists"] div[class="col"] a')->each) {
                my $article_link = $domain.$word_link2->attr('href');
                my $word = $word_link2->content;
                
                next if is_stored($word);
                
                my $content = get_url($article_link);
                #$content = decode("utf8", $content);
                for my $url_link (find_sound_links(\$content)) {
                    next if -e $sound_dir.$url_link;
                    make_path($sound_dir, $url_link);
                    get_url($domain.$url_link, ':content_file' => $sound_dir.$url_link);
                }
                write_to_db($word, \$content);
            }
        }
    }
}

print "finished!\n";

###################################################################################
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

sub html_washer {
    my $html = shift;
    
    my $dom = Mojo::DOM->new($$html);
    $$html = undef;
    for my $data ($dom->find('div[class="definition_content col main_bar"]')->each) {
        #for my $garbage ($data->children('div[class="term-subsec"]')->each) { # IT WILL ALSO REMOVE EXAMPLE BLOCK IN DICTIONARIES!!!
        for my $garbage ($data->children('#advert_box')->each) {
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

sub write_to_db {
    my $word = shift;
    my $content = shift;
    
    html_washer($content);
    $$content =~ s/\s+/ /sg;
    
    unless ($$content) {
        $word ||= 'NULL';
        print "no entry: $word\n";
        return;
    }
    $word = decode_entities($word);
    $load_basic->execute($word, $$content, $source, $target, $dictionary, $version, $alias);
    print $n++, '> ', $word, "\n";
    
    return 1;
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
