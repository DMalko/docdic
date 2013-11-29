#!/usr/bin/perl

use strict;
use warnings;

use utf8;
use Roman;

use DBI;
use Encode;
use File::Temp;

###################################
#my $dic_source_name = 'LingvoUniversalEnRu_2.4.2';
my $dic_source_name = 'LingvoUniversalRuEn_2.4.2';
my $sorce = 'ru';
my $target = 'en';
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
            `example` text,
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

my $load_basic = $dbh->prepare(q/LOAD DATA LOCAl INFILE ? INTO TABLE `dic_lingvo_basic` CHARACTER SET UTF8/);
my $load_col = $dbh->prepare(q/LOAD DATA LOCAl INFILE ? INTO TABLE `dic_lingvo_col` CHARACTER SET UTF8/);
my $load_ex = $dbh->prepare(q/LOAD DATA LOCAl INFILE ? INTO TABLE `dic_lingvo_ex` CHARACTER SET UTF8/);
my $load_group = $dbh->prepare(q/LOAD DATA LOCAl INFILE ? INTO TABLE `dic_lingvo_group` CHARACTER SET UTF8/);
my $load_syn = $dbh->prepare(q/LOAD DATA LOCAl INFILE ? INTO TABLE `dic_lingvo_syn` CHARACTER SET UTF8/);

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

my $tmp_basic = File::Temp->new();
my $tmp_group = File::Temp->new();
my $tmp_syn   = File::Temp->new();
my $tmp_ex    = File::Temp->new();
my $tmp_col   = File::Temp->new();
binmode($tmp_basic, ":encoding(utf8)");
binmode($tmp_group, ":encoding(utf8)");
binmode($tmp_syn, ":encoding(utf8)");
binmode($tmp_ex, ":encoding(utf8)");
binmode($tmp_col, ":encoding(utf8)");

open(LOG, ">log.txt") || die;
binmode(LOG, ":encoding(utf8)");
$query->execute($dic_source_name);
while (my ($id, $keyword, $data) = $query->fetchrow_array()) {
    print  $id, "\n";
    my @strings = split(/\n/, $data);
    
    (shift @strings) =~ m/<k>(.*)<\/k>/;
    
    my %trn = ();
    my $variant = 0; # I II III IV V
    my $type;        # 1. 2. 3. 4. 5. (сущ. прил. гл.)
    my $record = 0;  # 1) 2) 3) 4) 5)
    my $transcription;
    my $translation;
    
    for (my $i = 0; $i < @strings; $i++) {
        # part of speech
        if (!$i && $strings[$i] =~ m/^(<.*>)/ && $strings[$i] !~ m/^<b>|<tr>|<dtrn>|<ex>|<iref>/) {
            $type = rm_tag($1);
        }
        
        # collocation        
        if ($strings[$i] =~ m/^- *(<.*>)/) {
            if (exists $trn{$variant} && @{$trn{$variant}}) {
                my $last_rec = @{$trn{$variant}}[-1];
                push @{$$last_rec{col}}, $1;
            } else {
                print LOG $keyword, "\tno record for collocation\n";
            }
        }
        
        # variant
        if ($strings[$i] =~ m/^<b>([IVX]+)<\/b> *(<.*>)?/) {
            $variant = arabic($1);
            $record = 0;
            $type = undef;
            # part of speech
            if ($2 && $strings[$i] !~ m/<tr>|<dtrn>|<ex>|<iref>/) {      
               $type = rm_tag($2);
            } else {
                if ($i + 1 < @strings && $strings[$i + 1] =~ m/^(<.*>)/) {
                    $type = rm_tag($1) if $strings[$i + 1] !~ m/^<b>|<tr>|<dtrn>|<ex>|<iref>/;
                } else {
                    print LOG $keyword, "\tno type\n";
                }
            }
        }
        
        # part of speech
        if ($strings[$i] =~ m/<b>\d+\.<\/b> *(<.*>)?/) {
            $record = 0;
            $type = undef;
            if ($1 && $strings[$i] !~ m/<tr>|<dtrn>|<ex>|<iref>/) {
               $type = rm_tag($1);
            } else {
                if ($i + 1 < @strings && $strings[$i + 1] =~ m/^(<.*>)/ && $strings[$i + 1] !~ m/^<b>|<tr>|<dtrn>|<ex>|<iref>/) {
                    $type = rm_tag($1);
                } else {
                    print LOG $keyword, "\tno type\n";
                }
            }
        }
        
        # transcription
        if ($strings[$i] =~ m/^<tr>(.+?)<\/tr>/) {
            $transcription = $1;
            # part of speech
            if ($i + 1 < @strings && $strings[$i + 1] =~ m/^(<.*>)/ && $strings[$i + 1] !~ m/^<b>|<tr>|<dtrn>|<ex>|<iref>/) {
                $type = rm_tag($1);
            }
        } elsif ($strings[$i] =~ m/<tr>(.+?)<\/tr>/) {
            $transcription = $1;
        }
        
        # record number
        $record = $1 if $strings[$i] =~ m/^(\d+)\)/;
        
        # translation
        if ($strings[$i] =~ m/<dtrn>(.+?)<\/dtrn>/ ||
                $strings[$i] =~ m/(?:<[^<>]+>)* *(= *<kref>(?:<[^<>]+>)*[^<>]+(?:<\/[^<>]+>)*<\/kref>)/) {
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
                $$last_rec{syn} = \@syn if @syn;
            } else {
                print LOG $keyword, "\tno record for synonyms\n";
                #die "ERROR: keyword_id $id (string $i) - no record for synonyms\n"
            }
        }
        
        # examples
        if ($strings[$i] =~ m/^<ex>(.+)<\/ex>/) {
            if (exists $trn{$variant} && @{$trn{$variant}}) {
                my $last_rec = @{$trn{$variant}}[-1];
                push @{$$last_rec{ex}}, $1;
            } else {
                print LOG $keyword, "\tno record for examples\n";
                #die "ERROR: keyword_id $id (string $i) - no record for examples\n"
            }
        }
    }
    
    for my $variant (sort {$a <=> $b} keys %trn) {
        $tmp_basic->print(join("\t", ++$keyword_id, $keyword, $variant, $sorce, $target, $dic_source_name), "\n");
        for my $rec (@{$trn{$variant}}) {
            $tmp_group->print(join("\t", ++$group_id, $keyword_id, $rec->{type}, $rec->{num}, $rec->{tr}, $rec->{trn}), "\n");
            if (exists $rec->{syn}) {
                for my $syn (@{$rec->{syn}}) {
                    $tmp_syn->print(join("\t", ++$syn_id, $group_id, $syn), "\n");
                }
            }
            if (exists $rec->{ex}) {
                for my $ex (@{$rec->{ex}}) {
                    $tmp_ex->print(join("\t", ++$ex_id, $group_id, $ex), "\n");
                }
            }
            if (exists $rec->{col}) {
                for my $col (@{$rec->{col}}) {
                    $tmp_col->print(join("\t", ++$col_id, $group_id, $col), "\n");
                }
            }
        }
    }
    
    1;
}
close LOG;
$tmp_col->close();
$tmp_ex->close();
$tmp_syn->close();
$tmp_group->close();
$tmp_basic->close();

print "loading database... ";
$load_col->execute($tmp_col);
$load_ex->execute($tmp_ex);
$load_syn->execute($tmp_syn);
$load_group->execute($tmp_group);
$load_basic->execute($tmp_basic);
print "ok\n";

print "done\n";

################## subroutines ###################

sub rm_tag {
    my $str = shift;    
    $str =~ s/<[a-z\/]+>//sg;    
    return $str;
}

##################################################



