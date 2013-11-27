#!/usr/bin/perl

use strict;
use warnings;
use XML::Simple;

###################################
my $wiki_dir = "../data/common_words/ini/wiki";
###################################

my $xml = new XML::Simple (NoAttr=>1);
open (OUT, ">:utf8", "wiki.file") || die;
while (my $wiki_file = glob("$wiki_dir/*")) {
    open(IN, "$wiki_file") || die;
    read(IN, my $str, (stat(IN))[7]);
    close IN;
    $str =~ s/.*?(<table>.*?<\/table>).*/$1/s;
    my $data = $xml->XMLin($str);
    shift @$data{tr};
    for my $field (@{$data->{tr}}) {
        my $rank = $field->{td}[0];
        my $word = $field->{td}[1]{a};
        my $count = $field->{td}[2];
        unless ($rank && $word && $count) {
            print $wiki_file, "\n";
            print "pass: rank=$rank, word=$word\n";
            next;
        }
        print OUT join ("\t", $rank, $word, $count), "\n";
    }
}
close OUT;
print "finished!\n";
