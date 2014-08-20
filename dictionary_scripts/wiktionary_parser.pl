#! /usr/bin/perl

### !!! before `Wiktionary::Parser` install `Locale::Codes::Language` !!! ###

use warnings;
use strict;

use Wiktionary::Parser;

############################################################
my $wordfile = '../words.list';
my $output = '../wiktionary.pron';
my $out_dir = '../data/pronunciations/Wiktionary';
############################################################

open(IN, '<encoding(utf8)', $wordfile) || die "$!\n";
open(OUT, '>encoding(utf8)', $output) || die "$!\n";
my $parser = Wiktionary::Parser->new();
my %downloaded = map {s/.*\///; s/^"//;  s/"$//;($_, 1)} glob($out_dir.'/*.ogg');
while(<IN>) {  
    chomp;
    print "word: ", $_, "\n";
    my $document = $parser->get_document(title => $_);
    next unless $document;
    
    my $translation_hashref     = $document->get_translations();
    my $word_sense_hashref      = $document->get_word_senses();
    my $parts_of_speech_hashref = $document->get_parts_of_speech();
    my $pronunciations_hashref  = $document->get_pronunciations();
    my $synonyms_hashref        = $document->get_synonyms();
    my $hyponyms_hashref        = $document->get_hyponyms();
    my $hypernyms_hashref       = $document->get_hypernyms();
    my $antonyms_hashref        = $document->get_antonyms();
    my $derived_terms_hashref   = $document->get_derived_terms();
    
    my $section_hashref = $document->get_sections();
        my $sub_document = $document->get_sub_document(title => 'string or regex');
        my $table_of_contents_arrayref = $document->get_table_of_contents();
    
    my $pron = $document->get_pronunciations();
    my $audio = $pron->{en}{audio};
    if ($audio) {
        for my $aud (@$audio) {
            next if exists $downloaded{$aud->get_file()};
            $aud->download_file(directory => $out_dir);
            print OUT join("\t", $_, $aud->get_text(), $aud->get_file()), "\n";
            print $aud->get_file(), "\n";   
        }
    }    
}
close OUT;

print "finished!\n";


__END__

# original code:

# This example uses the get_pronunciations() method to print out
# structured data pulled from the pronunciation sections of a
# wiktionary page.

my $word = 'cat';
my $parser = Wiktionary::Parser->new();
my $document = $parser->get_document(title => $word);

my $pron = $document->get_pronunciations();

for my $language_code (sort keys %{ $pron || {} }) {
    my $pronunciation = $pron->{$language_code}{pronunciation};
    my $audio = $pron->{$language_code}{audio};
    my $rhyme = $pron->{$language_code}{rhyme};
    my $homophone = $pron->{$language_code}{homophone};
    
    # not necessary related to pronunciation,
    # but present in this section on some page like 'forward'
    my $hyphenation = $pron->{$language_code}{hyphenation};
    
    my $language_name = $pron->{$language_code}{language};
    
    print "\n Language: $language_name, Code: $language_code\n";
    
    if ($pronunciation) {
        print "\n\t Pronunciations: \n";
        for my $representation (@$pronunciation) {
            printf("\t\t%s: %s\n", $representation->get_representation(), join(', ', map {encode('utf8',$_)} @{ $representation->get_pronunciation() },));
        }
    }
    
    # if there are audio files linked to these pronunciations
    # the audio objects provide methods for downloading the .ogg files
    if ($audio) {
        for my $aud (@$audio) {
            printf("\n\t Audio Available: %s, File: %s\n",
            $aud->get_text(),
            $aud->get_file(),	
            );
            
            ##
            # uncomment this to download the .ogg files
            # to the specified direcory on your local machine
            $aud->download_file(directory => '../data/pronunciations')
        }    
    }
}
