LOAD DATA LOCAL INFILE '/data/bioprojects/Dictionary/data/dic/ini/LingvoUniER2Google.dump' 
INTO TABLE source_google character set UTF8;

LOAD DATA LOCAL INFILE '/data/bioprojects/Dictionary/data/dic/ini/LingvoUniRE2Google.dump' 
INTO TABLE source_google character set UTF8;
