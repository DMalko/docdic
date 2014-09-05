#!/usr/bin/perl

use strict;
use warnings;

# the script to clean up an css file from unused styles
# usage:
# css_extractor.pl helpful_classes_file css_file

my ($list_file, $css_file) = @ARGV;

#$list_file ||= 'collins_www_css.classes.learn.txt';
#$css_file ||= 'collins.original.css';

open(CSS, '<', $css_file) || die "ERROR: $css_file - wrong file name\n";
my $css = join '', <CSS>;
close CSS;

open(LIST, '<', $list_file) || die "ERROR: $list_file - wrong file name\n";
my %class_list = map {chomp($_);($_, 1)} <LIST>;
close LIST;

open(OUT, '>', $css_file.'.clean') || die "ERROR: can't open output file\n";
while ($css =~ m/(?:^|\})\s*([^}{]+)(\{[^}]+)/sgi) {
    my $prop = $2;
    my @classes = split(/ *, */, $1);
    my @inlist = ();
    for my $class (@classes) {
        if ($class =~ m/\.([-a-z0-9_]+)/sgi) {
            next unless exists $class_list{$1};
            push @inlist, $class;
        } else {
            push @inlist, $class;
        }
    }
    print OUT join(',', @inlist).$prop."}\n" if @inlist;
}
close OUT;

print "...done\n";
