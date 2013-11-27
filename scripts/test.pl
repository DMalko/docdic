#!/usr/bin/perl -w
use strict;



# 1
'AB' =~ /(A (A|B(*ACCEPT)|C) D)(E)/x;
my $l1 = $1;
my $l2 = $2;
my $l3 = $3;
my $l4 = $4;
1;

#2
my @array = 1,2,3,4;
my $ar = @array;
1;