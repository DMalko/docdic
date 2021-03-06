CREATE DATABASE  IF NOT EXISTS `Dictionary` /*!40100 DEFAULT CHARACTER SET latin1 */;
USE `Dictionary`;
-- MySQL dump 10.13  Distrib 5.5.34, for debian-linux-gnu (x86_64)
--
-- Host: localhost    Database: Dictionary
-- ------------------------------------------------------
-- Server version	5.5.34-0ubuntu0.12.04.1

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `card`
--

DROP TABLE IF EXISTS `card`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `card` (
  `card_id` int(11) NOT NULL AUTO_INCREMENT,
  `legacy_card_id` int(11) DEFAULT NULL,
  `source` char(32) DEFAULT NULL,
  `target` char(32) DEFAULT NULL,
  `card_type` char(64) DEFAULT NULL,
  `keyword` text,
  `main_translation` text,
  `user_id` int(11) DEFAULT '0',
  `created` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`card_id`),
  KEY `legacy_card_id` (`legacy_card_id`),
  KEY `keyword` (`keyword`(255)),
  KEY `translation` (`main_translation`(255)),
  KEY `user_id` (`user_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `card_frm`
--

DROP TABLE IF EXISTS `card_frm`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `card_frm` (
  `frm_id` int(11) NOT NULL AUTO_INCREMENT,
  `card_id` int(11) NOT NULL,
  `form` char(255) DEFAULT NULL,
  PRIMARY KEY (`frm_id`),
  KEY `card_id` (`card_id`),
  KEY `form` (`form`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `card_set`
--

DROP TABLE IF EXISTS `card_set`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `card_set` (
  `set_id` int(11) NOT NULL AUTO_INCREMENT,
  `name` text,
  `size` int(11) DEFAULT '0',
  `user_id` int(11) DEFAULT '0',
  `created` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`set_id`),
  KEY `user_id` (`user_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `card_stack`
--

DROP TABLE IF EXISTS `card_stack`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `card_stack` (
  `set_id` int(11) NOT NULL,
  `card_id` int(11) NOT NULL,
  PRIMARY KEY (`set_id`,`card_id`),
  KEY `card_id` (`card_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `card_trn`
--

DROP TABLE IF EXISTS `card_trn`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `card_trn` (
  `trn_id` int(11) NOT NULL AUTO_INCREMENT,
  `card_id` int(11) NOT NULL,
  `type` char(64) DEFAULT NULL,
  `translation` text,
  `score` float DEFAULT NULL,
  PRIMARY KEY (`trn_id`),
  KEY `card_id` (`card_id`),
  KEY `translation` (`translation`(255))
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `card_trs`
--

DROP TABLE IF EXISTS `card_trs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `card_trs` (
  `trs_id` int(11) NOT NULL AUTO_INCREMENT,
  `trn_id` int(11) NOT NULL,
  `transcription` char(128) DEFAULT NULL,
  PRIMARY KEY (`trs_id`),
  KEY `trn_id` (`trn_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `card_tsnd`
--

DROP TABLE IF EXISTS `card_tsnd`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `card_tsnd` (
  `tsnd_id` int(11) NOT NULL AUTO_INCREMENT,
  `trn_id` int(11) NOT NULL,
  `soundfile` char(255) DEFAULT NULL,
  PRIMARY KEY (`tsnd_id`),
  KEY `trn_id` (`trn_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `card_user_opinion`
--

DROP TABLE IF EXISTS `card_user_opinion`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `card_user_opinion` (
  `uop_id` int(11) NOT NULL AUTO_INCREMENT,
  `card_id` int(11) NOT NULL,
  `user_id` int(11) DEFAULT '0',
  `type` enum('like','dislike') DEFAULT NULL,
  `comment` text,
  `created` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`uop_id`),
  KEY `card_id` (`card_id`),
  KEY `user_id` (`user_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `card_user_set`
--

DROP TABLE IF EXISTS `card_user_set`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `card_user_set` (
  `set_id` int(11) NOT NULL,
  `user_id` int(11) DEFAULT '0',
  `active_state` tinyint(1) DEFAULT '0',
  `last_access` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY `set_id` (`set_id`,`user_id`),
  KEY `user_id` (`user_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `card_user_stat`
--

DROP TABLE IF EXISTS `card_user_stat`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `card_user_stat` (
  `card_id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) DEFAULT '0',
  `true` int(11) DEFAULT '0',
  `false` int(11) DEFAULT '0',
  `completeness` float DEFAULT '0',
  `last_result` enum('true','false') DEFAULT NULL,
  `last_access` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY `card_id` (`card_id`,`user_id`),
  KEY `user_id` (`user_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `dic_google2lingvo`
--

DROP TABLE IF EXISTS `dic_google2lingvo`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `dic_google2lingvo` (
  `google_keyword_id` int(11) NOT NULL,
  `lingvo_keyword_id` int(11) NOT NULL,
  `keyword` char(128) DEFAULT NULL,
  `google_trn_id` int(11) NOT NULL,
  `lingvo_group_id` int(11) NOT NULL,
  KEY `google_keyword_id` (`google_keyword_id`),
  KEY `lingvo_keyword_id` (`lingvo_keyword_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='utf8_general_ci';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `dic_google_basic`
--

DROP TABLE IF EXISTS `dic_google_basic`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `dic_google_basic` (
  `keyword_id` int(11) NOT NULL AUTO_INCREMENT,
  `keyword` char(128) DEFAULT NULL,
  `translation` char(128) DEFAULT NULL,
  `source` char(2) DEFAULT NULL,
  `target` char(2) DEFAULT NULL,
  `dictionary` char(64) DEFAULT NULL,
  PRIMARY KEY (`keyword_id`),
  KEY `keyword` (`keyword`)
) ENGINE=MyISAM AUTO_INCREMENT=181406 DEFAULT CHARSET=utf8 COMMENT='utf8_general_ci';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `dic_google_rtrn`
--

DROP TABLE IF EXISTS `dic_google_rtrn`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `dic_google_rtrn` (
  `rtrn_id` int(11) NOT NULL AUTO_INCREMENT,
  `trn_id` int(11) DEFAULT NULL,
  `keyword_id` int(11) DEFAULT NULL,
  `rtranslation` char(128) DEFAULT NULL,
  PRIMARY KEY (`rtrn_id`),
  KEY `trn_id` (`trn_id`),
  KEY `keyword_id` (`keyword_id`),
  KEY `rtranslation` (`rtranslation`)
) ENGINE=MyISAM AUTO_INCREMENT=1490269 DEFAULT CHARSET=utf8 COMMENT='utf8_general_ci';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `dic_google_trn`
--

DROP TABLE IF EXISTS `dic_google_trn`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `dic_google_trn` (
  `trn_id` int(11) NOT NULL AUTO_INCREMENT,
  `keyword_id` int(11) DEFAULT NULL,
  `type` char(32) DEFAULT NULL,
  `translation` char(128) DEFAULT NULL,
  `score` float DEFAULT NULL,
  PRIMARY KEY (`trn_id`),
  KEY `keyword_id` (`keyword_id`),
  KEY `translation` (`translation`)
) ENGINE=MyISAM AUTO_INCREMENT=404261 DEFAULT CHARSET=utf8 COMMENT='utf8_general_ci';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `dic_lingvo_basic`
--

DROP TABLE IF EXISTS `dic_lingvo_basic`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `dic_lingvo_basic` (
  `keyword_id` int(11) NOT NULL AUTO_INCREMENT,
  `keyword` char(128) DEFAULT NULL,
  `variant` int(11) DEFAULT NULL,
  `source` char(2) DEFAULT NULL,
  `target` char(2) DEFAULT NULL,
  `dictionary` char(64) DEFAULT NULL,
  PRIMARY KEY (`keyword_id`),
  KEY `keyword` (`keyword`)
) ENGINE=MyISAM AUTO_INCREMENT=179971 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `dic_lingvo_col`
--

DROP TABLE IF EXISTS `dic_lingvo_col`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `dic_lingvo_col` (
  `col_id` int(11) NOT NULL AUTO_INCREMENT,
  `group_id` int(11) DEFAULT NULL,
  `collocation` char(128) DEFAULT NULL,
  PRIMARY KEY (`col_id`),
  KEY `group_id` (`group_id`),
  KEY `collocation` (`collocation`)
) ENGINE=MyISAM AUTO_INCREMENT=32871 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `dic_lingvo_ex`
--

DROP TABLE IF EXISTS `dic_lingvo_ex`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `dic_lingvo_ex` (
  `ex_id` int(11) NOT NULL AUTO_INCREMENT,
  `group_id` int(11) DEFAULT NULL,
  `example` text,
  PRIMARY KEY (`ex_id`),
  KEY `group_id` (`group_id`)
) ENGINE=MyISAM AUTO_INCREMENT=112609 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `dic_lingvo_group`
--

DROP TABLE IF EXISTS `dic_lingvo_group`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `dic_lingvo_group` (
  `group_id` int(11) NOT NULL AUTO_INCREMENT,
  `keyword_id` int(11) DEFAULT NULL,
  `type` char(32) DEFAULT NULL,
  `record_num` int(3) DEFAULT NULL,
  `transcription` char(128) DEFAULT NULL,
  `translation` char(128) DEFAULT NULL,
  PRIMARY KEY (`group_id`),
  KEY `keyword_id` (`keyword_id`)
) ENGINE=MyISAM AUTO_INCREMENT=298891 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `dic_lingvo_syn`
--

DROP TABLE IF EXISTS `dic_lingvo_syn`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `dic_lingvo_syn` (
  `syn_id` int(11) NOT NULL AUTO_INCREMENT,
  `group_id` int(11) DEFAULT NULL,
  `synonym` char(128) DEFAULT NULL,
  PRIMARY KEY (`syn_id`),
  KEY `group_id` (`group_id`),
  KEY `synonym` (`synonym`)
) ENGINE=MyISAM AUTO_INCREMENT=99619 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `manual`
--

DROP TABLE IF EXISTS `manual`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `manual` (
  `table_name` text NOT NULL,
  `comments` text,
  PRIMARY KEY (`table_name`(128))
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='utf8_general_ci';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `source_google`
--

DROP TABLE IF EXISTS `source_google`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `source_google` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `dictionary` char(64) DEFAULT NULL,
  `keyword` char(128) DEFAULT NULL,
  `definition` longtext,
  PRIMARY KEY (`id`),
  KEY `keyword` (`keyword`)
) ENGINE=MyISAM AUTO_INCREMENT=276311 DEFAULT CHARSET=utf8 COMMENT='utf8_general_ci';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `source_lingvo`
--

DROP TABLE IF EXISTS `source_lingvo`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `source_lingvo` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `dictionary` char(64) DEFAULT NULL,
  `keyword` char(128) DEFAULT NULL,
  `definition` text,
  PRIMARY KEY (`id`),
  KEY `keyword` (`keyword`)
) ENGINE=MyISAM AUTO_INCREMENT=181516 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `source_wiktionary`
--

DROP TABLE IF EXISTS `source_wiktionary`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `source_wiktionary` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `dictionary` char(64) DEFAULT NULL,
  `keyword` char(128) DEFAULT NULL,
  `definition` text CHARACTER SET utf8mb4,
  PRIMARY KEY (`id`),
  KEY `keyword` (`keyword`)
) ENGINE=MyISAM AUTO_INCREMENT=493030 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `word_rank_ccae`
--

DROP TABLE IF EXISTS `word_rank_ccae`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `word_rank_ccae` (
  `rank` int(11) NOT NULL,
  `word` char(64) CHARACTER SET utf8 COLLATE utf8_bin DEFAULT NULL,
  `frequency` int(11) DEFAULT NULL,
  KEY `rank` (`rank`),
  KEY `word` (`word`)
) ENGINE=MyISAM AUTO_INCREMENT=5001 DEFAULT CHARSET=latin1 COMMENT='latin1_swedish_ci';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `word_rank_gutenberg`
--

DROP TABLE IF EXISTS `word_rank_gutenberg`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `word_rank_gutenberg` (
  `rank` int(11) NOT NULL,
  `word` char(64) CHARACTER SET utf8 COLLATE utf8_bin DEFAULT NULL,
  `frequency` int(11) DEFAULT NULL,
  KEY `rank` (`rank`),
  KEY `word` (`word`)
) ENGINE=MyISAM AUTO_INCREMENT=36409 DEFAULT CHARSET=latin1 COMMENT='latin1_swedish_ci';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `word_rank_movie`
--

DROP TABLE IF EXISTS `word_rank_movie`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `word_rank_movie` (
  `rank` int(11) NOT NULL,
  `word` char(64) CHARACTER SET utf8 COLLATE utf8_bin DEFAULT NULL,
  `frequency` int(11) DEFAULT NULL,
  KEY `rank` (`rank`),
  KEY `word` (`word`)
) ENGINE=MyISAM AUTO_INCREMENT=41285 DEFAULT CHARSET=latin1 COMMENT='latin1_swedish_ci';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `word_rank_simpsons`
--

DROP TABLE IF EXISTS `word_rank_simpsons`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `word_rank_simpsons` (
  `rank` int(11) NOT NULL,
  `word` char(64) CHARACTER SET utf8 COLLATE utf8_bin DEFAULT NULL,
  `frequency` int(11) DEFAULT NULL,
  KEY `word` (`word`),
  KEY `rank` (`rank`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1 COMMENT='latin1_swedish_ci';
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2013-12-06 17:42:30
