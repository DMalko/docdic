#!/usr/bin/perl

use strict;
use warnings;
use DBI;
use File::Temp;
use utf8;

###################################
my $dic_source_name = "Collins COBUILD Advanced Learner's English Dictionary";
my $sorce = 'en';
my $target = 'en';
my $clean = 0; # DROP TABLE source : 1 = yes, 0 = no

my $db_name = 'Dictionary';
my $host = 'localhost';
my $login = 'root';
my $password = '';
###################################

my $dbh = DBI->connect("DBI:mysql:$db_name:$host;mysql_local_infile=1", $login, $password, {RaiseError => 1, PrintError => 0, mysql_enable_utf8 => 1}) || die "$DBI::err($DBI::errstr)\n";

$dbh->do('DROP TABLE IF EXISTS `dic_collins_basic`') if $clean;
$dbh->do('CREATE TABLE IF NOT EXISTS `dic_collins_basic` (
        `keyword_id` int(11) NOT NULL AUTO_INCREMENT,
        `keyword` char(128) DEFAULT NULL,
        `body` text,
        `source` char(2) DEFAULT NULL,
        `target` char(2) DEFAULT NULL,
        `dictionary` char(64) DEFAULT NULL,
        PRIMARY KEY (`keyword_id`),
        KEY `keyword` (`keyword`)
    )DEFAULT CHARSET=utf8'
);

$dbh->do('DROP TABLE IF EXISTS `dic_collins_form`') if $clean;
$dbh->do('CREATE TABLE IF NOT EXISTS `dic_collins_form` (
        `form_id` int(11) NOT NULL AUTO_INCREMENT,
        `keyword_id` int(11) DEFAULT NULL,
        `wordform` char(128) DEFAULT NULL,
        `also_use` tinyint(1) NOT NULL,
        PRIMARY KEY (`form_id`),
        UNIQUE KEY `keyword_id` (`keyword_id`, `wordform`),
        KEY `wordform` (`wordform`)
    )DEFAULT CHARSET=utf8'
);

my $load_basic = $dbh->prepare(q/LOAD DATA LOCAl INFILE ? INTO TABLE `dic_collins_basic` CHARACTER SET UTF8 FIELDS TERMINATED BY '\r' LINES TERMINATED BY '\r\r'/);
my $load_form = $dbh->prepare(q/LOAD DATA LOCAl INFILE ? INTO TABLE `dic_collins_form` CHARACTER SET UTF8 FIELDS TERMINATED BY '\r' LINES TERMINATED BY '\r\r'/);

my $query = $dbh->prepare(q/SELECT id, keyword, definition FROM source_collins ORDER BY id/);


my $keyword_id = ($dbh->selectrow_array(q/SELECT MAX(keyword_id) FROM dic_collins_basic/))[0];
my $form_id = ($dbh->selectrow_array(q/SELECT MAX(form_id) FROM dic_collins_form/))[0];

$keyword_id ||= 0;
$form_id ||= 0;

my $tmp1 = File::Temp->new();
my $tmp2 = File::Temp->new();
binmode($tmp1, ":encoding(utf8)");
binmode($tmp2, ":encoding(utf8)");

my %tags = ();
$query->execute();
while (my ($id, $keyword, $data) = $query->fetchrow_array()) {
    #print  $id, "\n";
    $data =~ s/&eacute;/é/g;
    $data =~ s/&agrave;/à/g;
    $data =~ s/&egrave;/è/g;
    $data =~ s/&acirc;/â/g;
    $data =~ s/&ntilde;/ñ/g;
    $data =~ s/&amp;/&/g;
    
    while($data =~ m/\<([^>]+)\>/sg) {
        $tags{$1}++;
    }
    
    (my $forms = $data) =~ s/^[^-A-Z_0-9'.,&;\/]*\<BR\>//i;
    $forms =~ s/\<BR\>.*//;
    $forms =~ s/&middot;//sg;
    
    my @also_use = ();
    while($forms =~ m/use (\<B\>[^<>]+\<\/B\>(?:, *\<B\>[^<>]+\<\/B\>)*)/g) {
        push @also_use, map {s/\<\/?B\>//g; s/^ +//; s/ +$//; $_} split(/, */, $1);
    }
    
    $forms =~ s/ *Pronounced for meaning.*//;
    $forms =~ s/ *In addition to the uses shown below.*//;
    $forms =~ s/ +USED AS .*//;
    
    my $comments = '';
    if($forms =~ s/ +(in +(?:AM|BRIT).*)//s) {
        $comments = $1;
        $comments =~ s/ AM([^A-Z])/ AMERICAN$1/g;
        $comments =~ s/ BRIT([^A-Z])/ BRITISH$1/g;
    }
    if($keyword !~ m/[A-Z]/) {
        $forms =~ s/ *[A-Z].*//s;
    }
    $forms =~ s/ +\<.*//s;
    $forms =~ s/ +or +/ /sg;
    
    #print ">", $forms, "\n" if $keyword =~ m/[A-Z]/;
    #print ">", $forms, "\n" if $forms =~ m/,/;
    #print ">", $forms, "\n";
   
    my $comment = $1 ? $1 : '\N';
    my $wnum = scalar split(/ +/, $keyword);
    my @forms = ();
    while($forms =~ m/(?: *[-A-Z_0-9'.,&;\/]+){$wnum}/sgi) {
        my $word = $&;
        $word =~ s/^ +//;
        push @forms, $word;
    }
    
    $data =~ s/\<FONT color='#800000'/\<SPAN class="collins-redfont"/sg;
    $data =~ s/\<FONT color='#008080'/\<SPAN class="collins-olivefont"/sg;
    $data =~ s/\<FONT color='#000080'/\<SPAN class="collins-bluefont"/sg;
    $data =~ s/\<FONT color='#008000'/\<SPAN class="collins-greenfont"/sg;
    $data =~ s/\<\/FONT/\<\/SPAN/sg;
    
    $tmp1->print(join("\r", ++$keyword_id, $keyword, $data, $sorce, $target, $dic_source_name), "\r\r");
    for my $f (@forms) {
        $tmp2->print(join("\r", ++$form_id, $keyword_id, $f, '\N'), "\r\r");
    }
    for my $u (@also_use) {
        $tmp2->print(join("\r", ++$form_id, $keyword_id, $u, 1), "\r\r");
    }
}
$tmp1->close();
$tmp2->close();

$load_basic->execute($tmp1);
$load_form->execute($tmp2);

print "finished!\n";



