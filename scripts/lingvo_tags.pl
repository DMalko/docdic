#!/usr/bin/perl

use strict;
use warnings;

use DBI;
use XML::Simple;

###################################
my $db_name = 'Dictionary';
my $host = 'localhost';
my $login = 'root';
my $password = '';

my $outfile = 'lingvo.tags';
###################################

my $dbh = DBI->connect("DBI:mysql:$db_name:$host;mysql_local_infile=1", $login, $password, {RaiseError => 1, PrintError => 0, mysql_enable_utf8 => 1}) || die "$DBI::err($DBI::errstr)\n";
open(OUT, "> $outfile") || die;
my $select = $dbh->prepare('SELECT definition FROM source_lingvo');
$select->execute();
my %tags = ();
while(my $def = $select->fetchrow_array()){
    while($def =~ m/<[^>]+>/sg){
        $tags{$&}++;
    }
}
for my $tag (keys %tags){
    print OUT $tag, "\t", $tags{$tag}, "\n";
}
close OUT;

print "...done\n";
