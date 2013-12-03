CREATE TABLE `tmp_google2lingvo` (
  `google_keyword_id` int(11) NOT NULL,
  `lingvo_keyword_id` int(11) NOT NULL,
`keyword` char(128) DEFAULT NULL,
  KEY `google_keyword_id` (`google_keyword_id`),
  KEY `lingvo_keyword_id` (`lingvo_keyword_id`)
) DEFAULT CHARSET=utf8
SELECT t1.keyword_id AS google_keyword_id, t2.keyword_id AS lingvo_keyword_id, keyword
FROM dic_google_basic AS t1 INNER JOIN dic_lingvo_basic AS t2 USING(keyword)
WHERE keyword IS NOT NULL;

CREATE TABLE `dic_google2lingvo` (
  `google_keyword_id` int(11) NOT NULL,
  `lingvo_keyword_id` int(11) NOT NULL,
  `keyword` char(128) DEFAULT NULL,
`google_trn_id` int(11) NOT NULL,
`lingvo_group_id` int(11) NOT NULL,
  KEY `google_keyword_id` (`google_keyword_id`),
  KEY `lingvo_keyword_id` (`lingvo_keyword_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8
SELECT google_keyword_id, lingvo_keyword_id, keyword, trn_id AS google_trn_id, group_id AS lingvo_group_id
FROM tmp_google2lingvo AS t1 INNER JOIN dic_google_trn AS t2 
INNER JOIN dic_lingvo_group AS t3
ON t1.google_keyword_id = t2.keyword_id AND t1.lingvo_keyword_id = t3.keyword_id
WHERE t3.translation REGEXP t2.translation;

DROP tmp_google2lingvo;

