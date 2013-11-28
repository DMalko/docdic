#!/usr/bin/perl

use strict;
use warnings;

use utf8;
use Roman;

use DBI;
use Encode;
use File::Temp;

###################################
my $dic_source_name = 'LingvoUniversalEnRu_2.4.2';
#my $dic_source_name = 'LingvoUniversalRuEn_2.4.2';
my $sorce = 'en';
my $target = 'ru';
my $clean = 0; # DROP TABLE source : 1 = yes, 0 = no

my $db_name = 'Dictionary';
my $host = 'localhost';
my $login = 'root';
my $password = '';
###################################

my $dbh = DBI->connect("DBI:mysql:$db_name:$host;mysql_local_infile=1", $login, $password, {RaiseError => 1, PrintError => 0, mysql_enable_utf8 => 1}) || die "$DBI::err($DBI::errstr)\n";

$dbh->do('DROP TABLE IF EXISTS `dic_lingvo_basic`') if $clean;
$dbh->do('CREATE TABLE IF NOT EXISTS `dic_lingvo_basic` (
            `keyword_id` int(11) NOT NULL AUTO_INCREMENT,
            `keyword` char(128) DEFAULT NULL,
            `variant` int(11) DEFAULT NULL,
            `source` char(2) DEFAULT NULL,
            `target` char(2) DEFAULT NULL,
            `dictionary` char(64) DEFAULT NULL,
            PRIMARY KEY (`keyword_id`),
            KEY `keyword` (`keyword`)
          ) ENGINE=MyISAM DEFAULT CHARSET=utf8'
);

$dbh->do('DROP TABLE IF EXISTS `dic_lingvo_col`') if $clean;
$dbh->do('CREATE TABLE IF NOT EXISTS `dic_lingvo_col` (
            `col_id` int(11) NOT NULL AUTO_INCREMENT,
            `group_id` int(11) DEFAULT NULL,
            `collocation` char(128) DEFAULT NULL,
            PRIMARY KEY (`col_id`),
            KEY `group_id` (`group_id`),
            KEY `collocation` (`collocation`)
          ) DEFAULT CHARSET=utf8'
);

$dbh->do('DROP TABLE IF EXISTS `dic_lingvo_ex`') if $clean;
$dbh->do('CREATE TABLE IF NOT EXISTS `dic_lingvo_ex` (
            `ex_id` int(11) NOT NULL AUTO_INCREMENT,
            `group_id` int(11) DEFAULT NULL,
            `example` char(128) DEFAULT NULL,
            PRIMARY KEY (`ex_id`),
            KEY `group_id` (`group_id`)
          ) DEFAULT CHARSET=utf8'
);

$dbh->do('DROP TABLE IF EXISTS `dic_lingvo_group`') if $clean;
$dbh->do('CREATE TABLE IF NOT EXISTS `dic_lingvo_group` (
            `group_id` int(11) NOT NULL AUTO_INCREMENT,
            `keyword_id` int(11) DEFAULT NULL,
            `type` char(32) DEFAULT NULL,
            `record_num` int(3) DEFAULT NULL,
            `transcription` char(128) DEFAULT NULL,
            `translation` char(128) DEFAULT NULL,
            PRIMARY KEY (`group_id`),
            KEY `keyword_id` (`keyword_id`)
          ) ENGINE=MyISAM DEFAULT CHARSET=utf8'
);

$dbh->do('DROP TABLE IF EXISTS `dic_lingvo_syn`') if $clean;
$dbh->do('CREATE TABLE IF NOT EXISTS `dic_lingvo_syn` (
            `syn_id` int(11) NOT NULL AUTO_INCREMENT,
            `group_id` int(11) DEFAULT NULL,
            `synonym` char(128) DEFAULT NULL,
            PRIMARY KEY (`syn_id`),
            KEY `group_id` (`group_id`),
            KEY `synonym` (`synonym`)
          ) DEFAULT CHARSET=utf8'
);

my $load_basic = $dbh->prepare(q/LOAD DATA LOCAl INFILE ? INTO TABLE `dic_lingvo_basic` CHARACTER SET UTF8 FIELDS TERMINATED BY '\r' LINES TERMINATED BY '\r\r'/);
my $load_col = $dbh->prepare(q/LOAD DATA LOCAl INFILE ? INTO TABLE `dic_lingvo_col` CHARACTER SET UTF8 FIELDS TERMINATED BY '\r' LINES TERMINATED BY '\r\r'/);
my $load_ex = $dbh->prepare(q/LOAD DATA LOCAl INFILE ? INTO TABLE `dic_lingvo_ex` CHARACTER SET UTF8 FIELDS TERMINATED BY '\r' LINES TERMINATED BY '\r\r'/);
my $load_group = $dbh->prepare(q/LOAD DATA LOCAl INFILE ? INTO TABLE `dic_lingvo_group` CHARACTER SET UTF8 FIELDS TERMINATED BY '\r' LINES TERMINATED BY '\r\r'/);
my $load_syn = $dbh->prepare(q/LOAD DATA LOCAl INFILE ? INTO TABLE `dic_lingvo_syn` CHARACTER SET UTF8 FIELDS TERMINATED BY '\r' LINES TERMINATED BY '\r\r'/);

my $query = $dbh->prepare(q/SELECT id, keyword, definition FROM source_lingvo WHERE dictionary = ? ORDER BY id/);


my $keyword_id = ($dbh->selectrow_array(q/SELECT MAX(keyword_id) FROM dic_lingvo_basic/))[0];
my $col_id = ($dbh->selectrow_array(q/SELECT MAX(col_id) FROM dic_lingvo_col/))[0];
my $ex_id = ($dbh->selectrow_array(q/SELECT MAX(ex_id) FROM dic_lingvo_ex/))[0];
my $group_id = ($dbh->selectrow_array(q/SELECT MAX(group_id) FROM dic_lingvo_group/))[0];
my $syn_id = ($dbh->selectrow_array(q/SELECT MAX(syn_id) FROM dic_lingvo_syn/))[0];

$keyword_id ||= 0;
$col_id ||= 0;
$ex_id ||= 0;
$group_id ||= 0;
$syn_id ||= 0;

#my $tmp1 = File::Temp->new();
#my $tmp2 = File::Temp->new();
#my $tmp3 = File::Temp->new();
#binmode($tmp1, ":encoding(utf8)");
#binmode($tmp2, ":encoding(utf8)");
#binmode($tmp3, ":encoding(utf8)");

my %hash = ();
#open(LOG, ">log.txt") || die;
$query->execute($dic_source_name);
while (my ($id, $keyword, $data) = $query->fetchrow_array()) {
    print  $id, "\n";
    my @strings = split(/\n/, $data);
    
    (shift @strings) =~ m/<k>(.*)<\/k>/;
    die "ERROR: keyword_id $id - no keyword\n" if $1 ne $keyword;
    
    my %trn = ();
    my $variant = 0; # I II III IV V
    my $type;        # 1. 2. 3. 4. 5. (сущ. прил. гл.)
    my $record = 0;  # 1) 2) 3) 4) 5)
    my $transcription;
    my $translation;
    
    for (my $i = 0; $i < @strings; $i++) {
        # collocation
        if ($strings[$i] =~ m/^•/) {
            for (; $i < @strings; $i++) {
                last if $strings[$i] =~ m/^<b>(?:[IVX]+|d+[.)])<\/b>/;
                
                # code to extract collocations
                
            }
            last unless $i + 1 < @strings; 
        }        
        
        # variant
        if ($strings[$i] =~ m/^<b>([IVX]+)<\/b> *(?:(?:<[^<>]+>)*<abr>(?:<[^<>]+>)*([^<>]+)(?:<\/[^<>]+>)*<\/abr>)?/) {
            $variant = arabic($1);
            # part of speech
            if ($2) {
               $type = $2;
            } else {
                if ($i + 1 < @strings && $strings[$i + 1] =~ m/^(?:<[^<>]+>)*<abr>(?:<[^<>]+>)*([^<>]+)(?:<\/[^<>]+>)*<\/abr>/) {
                    $type = $1;
                } else {
                    die "ERROR: keyword_id $id (string $i) - no type\n"
                }
            }
        }
        
        # part of speech
        if ($strings[$i] =~ m/<b>\d+\.<\/b> *(?:(?:<[^<>]+>)*<abr>(?:<[^<>]+>)*([^<>]+)(?:<\/[^<>]+>)*<\/abr>)?/) {
            if ($1) {
               $type = $1;
            } else {
                if ($i + 1 < @strings && $strings[$i + 1] =~ m/^(?:<[^<>]+>)*<abr>(?:<[^<>]+>)*([^<>]+)(?:<\/[^<>]+>)*<\/abr>/) {
                    $type = $1;
                } else {
                    die "ERROR: keyword_id $id (string $i) - no type\n"
                }
            }
        }
        
        # transcription
        if ($strings[$i] =~ m/^<tr>(.+?)<\/tr>/) {
            $transcription = $1;
            # part of speech
            if ($i + 1 < @strings && $strings[$i + 1] =~ m/^(?:<[^<>]+>)*<abr>(?:<[^<>]+>)*([^<>]+)(?:<\/[^<>]+>)*<\/abr>/) {
                $type = $1;
            }
        } elsif ($strings[$i] =~ m/<tr>(.+?)<\/tr>/) {
            $transcription = $1;
        }
        
        # record number
        $record = $1 if $strings[$i] =~ m/^(\d+)\)/;
        
        # translation
        if ($strings[$i] =~ m/<dtrn>(.+?)<\/dtrn>/ ||
            $strings[$i] =~ m/(?:<[^<>]+>)* *= *<kref>(?:<[^<>]+>)*([^<>]+)(?:<\/[^<>]+>)*<\/kref>/) {
            $transcription ||= '\N';
            $type ||= '\N';
            push @{$trn{$variant}}, {trn => $1, tr => $transcription, num => $record, type => $type};
        }
        
        # synonyms
        if ($i + 1 < @strings && $strings[$i] =~ m/^<b>Syn:<\/b>/) {
            my @syn = ();
            while ($strings[$i + 1] =~ m/<kref>([^<>]+)<\/kref>/g) {
               push @syn, $1; 
            }
            if (exists $trn{$variant} && @{$trn{$variant}}) {
                my $last_rec = @{$trn{$variant}}[-1];
                $$last_rec{syn} = \@syn;
            } else {
                die "ERROR: keyword_id $id (string $i) - no record for synonyms\n"
            }
        }
        
        # examples
        if ($strings[$i] =~ m/^<ex>([^<>]+)<\/ex>/) {
            if (exists $trn{$variant} && @{$trn{$variant}}) {
                my $last_rec = @{$trn{$variant}}[-1];
                push @{$$last_rec{ex}}, $1;
            } else {
                die "ERROR: keyword_id $id (string $i) - no record for examples\n"
            }
        }
    }
    
    
    1;
}

1;

__END__


my $sss = '<abr><i><c><co>сущ.</co></c></i></abr>';

my $arabic = 15;
my $roman = 'IX';
$roman = roman($arabic);                        # convert to roman numerals
$arabic = arabic($roman) if isroman($roman);    # convert from roman numerals

$sss =~ m/.*(<(.*?)>.*?<(\/\2)>)/;
my $ss = $&;
my $ee = $1;
my $gg = $2;

1;