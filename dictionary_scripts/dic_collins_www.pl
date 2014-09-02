#!/usr/bin/perl

use strict;
use warnings;

use utf8;

use DBI;
use URI::Encode qw(uri_encode uri_decode);
use Encode qw (encode decode);
use JSON qw( decode_json from_json );
use Mojo::DOM;

###################################
my $source_dict_table = 'source_collins_www_learn';
my $db_name = 'wm_dict';
my $host = 'localhost';
my $login = 'root';
my $password = '';
my $clean = 1;
###################################

my $dbh = DBI->connect("DBI:mysql:$db_name:$host;mysql_local_infile=1", $login, $password, {RaiseError => 1, PrintError => 0, mysql_enable_utf8 => 1}) || die "$DBI::err($DBI::errstr)\n";

$dbh->do(q/DROP TABLE IF EXISTS `dict_collins`/) if $clean;
$dbh->do(q/CREATE TABLE IF NOT EXISTS `dict_collins` (
         `card_id` int(11) NOT NULL AUTO_INCREMENT,
         `keyword` varchar(128) DEFAULT NULL,
         `body` longtext,
         `source` varchar(3) DEFAULT NULL,
         `target` varchar(3) DEFAULT NULL,
         `dictionary` varchar(128) DEFAULT NULL,
         `version` varchar(128) DEFAULT NULL,
         `alias` varchar(32) DEFAULT NULL,
         `like` int(11) NOT NULL DEFAULT '0',
         `error` int(11) NOT NULL DEFAULT '0',
         `created` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
         PRIMARY KEY (`card_id`),
         KEY `keyword` (`keyword`,`source`,`target`,`alias`)
       ) ENGINE=MyISAM DEFAULT CHARSET=utf8
/);

my $select_article = $dbh->prepare(qq/SELECT * FROM $source_dict_table ORDER BY keyword/);
my $load_article = $dbh->prepare(q/INSERT INTO `dict_lingvo` (keyword, body, source, target, dictionary, version, alias) VALUES (?, ?, ?, ?, ?, ?, ?)/);

my %classes = (); # collect lingvo css classes

# lingvo container tags
my $tags_before = '<div class="l-article g-card">';
my $tags_after = '</div>';

$select_article->execute();
while (my ($id, $keyword, $article, $source, $target, $dictionary, $version, $alias) = $select_article->fetchrow_array()) {
    $article =~ s/Развернуть статью/Expand the entry/sg;
       
    my $dom = Mojo::DOM->new($article);
    
    # remake expand/collapse toggle
    for my $data ($dom->find('a[class="l-article__expandcollapse-link js-article-button"]')->each) {
        $data->content('<span class="l-article__expand hide"><span class="g-icons g-iblock l-article__toggle__icon"></span> Expand the entry</span><span class="l-article__collapse"><span class="g-icons g-iblock l-article__toggle__icon expanded"></span> Collapse the entry</span>');
    }
    
    # replace word tooltips
    for my $data ($dom->find('a[class="l-article__showExamp js-show-examples"]')->each) {
        $data->attr('title' => '');
    }
    # replace the transcription image by the text
    for my $p ($dom->find('p')->each) {
        my $is_transcr = 0;
        for my $data ($p->find('img[class="l-article__transcription"]')->each) {
            my $src = $data->attr('src');
            $src =~ s/.*\/transcription.gif\?Text=//;
            $src = uri_decode(encode("utf8", $src));
            $src = decode("utf8", $src);
            $data->replace(qq#<span class="l-article__transcription_text">$src</span>#);
            $is_transcr = 1; 
        }
        # add a class attribute to brackets and slashes in the transcription block
        if ($is_transcr) {
            my $string = $p->to_string;
            $string =~ s/>(\s*)\[(\s*)</>$1<span class="l-article__transcription_lbracket">\[<\/span>$2</sg;
            $string =~ s/>(\s*)\](\s*)</>$1<span class="l-article__transcription_rbracket">\]<\/span>$2</sg;
            $string =~ s/>(\s*)\/(\s*)</>$1<span class="l-article__transcription_slash">\/<\/span>$2</sg;
            $p->replace($string);
        }
    }
    # clean the flash content but remain 'data-flash-url' attribute that keeps a path to the sound file
    for my $data ($dom->find('span[class="l-article__sound"]')->each) {
        for my $jplayer ($data->find('span[class="jp-jplayer"]')) {
            my $url = $jplayer->attr('data-flash-url');
            $url =~ s/.*\?/\/members\/dictionary\/sound\?/;
            $jplayer->replace(qq#<span class="audio-link" data-url="$url"><audio></audio></span>#);
        }
        $data->find('span[class="js-lingvo-sound jp-audio"]')->remove;
    }
    # clean the dictionary info link
    for my $data ($dom->find('a[class="g-iblock l-article__linkdict js-dictionary-popup-trigger"]')->each) {
        my $dict_name = $data->text;
        $data->replace('<span class="g-iblock l-article__linkdict">'.$dict_name.'</span>');
    }
    
    my $html = $dom->to_string;

    my $body = $tags_before.$html.$tags_after;
    $load_article->execute($keyword, $body, $source, $target, $dictionary, $version, $alias) || die "ERROR: insertion fault - $keyword\n";
    
    # collect classes
    while ($body =~ m/class\s*=\s*"([^"]+)"/g) {
        map {$classes{$_} = 1} split(/\s+/, $1);
    }
}
open OUT, ">lingvo_www_css.classes.txt" || die;
print OUT join("\n", keys %classes) if keys %classes;
close OUT;

print "finished!\n";

