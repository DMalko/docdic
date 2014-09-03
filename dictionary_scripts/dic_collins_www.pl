#!/usr/bin/perl

use strict;
use warnings;

use utf8;

use DBI;
use URI::Encode qw(uri_encode uri_decode);
use Encode qw (encode decode);
use MIME::Base64 qw(encode_base64 decode_base64);
use Mojo::DOM;

###################################
my $source_dict_table = 'source_collins_www_thes';
my $db_name = 'wm_dict';
my $host = 'localhost';
my $login = 'root';
my $password = '';
my $clean = 0;
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
my $load_article = $dbh->prepare(q/INSERT INTO `dict_collins` (keyword, body, source, target, dictionary, version, alias) VALUES (?, ?, ?, ?, ?, ?, ?)/);

my %classes = (); # collect lingvo css classes

# lingvo container tags
my $tags_before = '<div class="collins dictionary"><div class="definition_wrapper"><div class="definition_main">';
my $tags_after = '</div></div></div>';

$select_article->execute();
while (my ($id, $keyword, $article, $source, $target, $dictionary, $version, $alias) = $select_article->fetchrow_array()) {
    my $dom = Mojo::DOM->new($article);
    my $dic_header = '<span class="dic-name">'.$dictionary.'</span>';
    
    # make a sound link
    for my $data ($dom->find('img.sound')->each) {
        my $link = $data->attr('onclick');
        if ($link =~ m/'\/sounds.*\/([^'\/]+)\.mp3'/i) {
            my $url = '/members/dictionary/sound?FileName='.encode_base64($1, '').'&DictionaryName='.uri_encode($dictionary);
            $data->replace(qq#<span class="audio-link" data-url="$url"><audio></audio></span>#);
        } else {
            print "ERROR: wrong sound link for `$keyword` ($link)\n";
            $data->remove;
        }
    }
    
    my $html = $dom->to_string;

    my $body = $tags_before.$dic_header.$html.$tags_after;
    $load_article->execute($keyword, $body, $source, $target, $dictionary, $version, $alias) || die "ERROR: insertion fault - $keyword\n";
    
    # collect classes
    while ($body =~ m/class\s*=\s*"([^"]+)"/g) {
        map {$classes{$_} = 1} split(/\s+/, $1);
    }
}
open OUT, ">collins_www_css.classes.txt" || die;
print OUT join("\n", keys %classes) if keys %classes;
close OUT;

print "finished!\n";

