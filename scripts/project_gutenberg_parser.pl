#!/usr/bin/perl

use strict;
use warnings;

###################################
my $wiki_dir = "../Project_Gutenberg";
###################################

open (OUT, ">:utf8", "wiki_pg.file") || die;
while (my $wiki_file = glob("$wiki_dir/*")) {
    open(IN, "$wiki_file") || die;
    read(IN, my $str, (stat(IN))[7]);
    close IN;
    while ($str =~ m/(\w+) = (\d+(?:.\d+))?/sg) {
        my $rank = $2;
        my $word = $1;
        print OUT join ("\t", '\N', $word, $rank), "\n";
    }
}
close OUT;
print "finished!\n";
