#!/usr/bin/perl
use strict;
use warnings;
use Web::Scraper;
use URI;
use YAML;

my $emoji = scraper {
  process '//table[@width="100%" and @cellpadding="2"]//tr/td/font/../..',
    'emoji[]' => scraper {
      process '//td[2]/font', unicode => 'TEXT';
      process '//td[3]/font', sjis => [ 'TEXT', sub { unpack "H*", shift } ];
    };
  result 'emoji';
};

my @urls = map "http://developers.softbankmobile.co.jp/dp/tool_dl/web/picword_0$_.php", 1..6;

my $res;
foreach my $url (@urls) { push @$res, @{$emoji->scrape(URI->new($url))} };
binmode STDOUT, ":utf8";
print Dump $res;
