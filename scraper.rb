#!/bin/env ruby
# encoding: utf-8

require 'scraperwiki'
require 'nokogiri'
require 'date'
require 'open-uri'
require 'date'
require 'csv'

# require 'colorize'
# require 'pry'
# require 'csv'
# require 'open-uri/cached'
# OpenURI::Cache.cache_path = '.cache'

def noko_for(url)
  Nokogiri::HTML(open(url).read) 
end

def datefrom(date)
  Date.parse(date)
end

def scrape_list(url)
  warn "Getting #{url}"
  noko = noko_for(url)
  noko.css('a[href*="mp.php"]/@href').map(&:text).uniq.each do |rel_link|
    abs_link = URI.join(url, rel_link)
    scrape_mp(abs_link)
  end

  next_page = noko.css('a[href*="mode=alps"]').find { |a| a.text.include? 'Next' }
  scrape_list(URI.join(url, next_page.attr('href'))) if next_page
end

def scrape_mp(url)
  noko = noko_for(url)
  heading = noko.xpath('.//font[@face="Palatino Linotype"]').first
  (name, constituency) = heading.text.strip.split(/\s+-\s+/)
  box = noko.xpath('.//table[contains(.,"Postal addrress")]').last
  party_info = box.css('a[href*="mode=pp"]').text
  (party, party_id) = party_info.match(/^(.*)\s\((.*?)\)/).captures rescue (party, party_id) = [party_info, party_info]

  data = { 
    id: url.to_s[/indexc=(\d+)/, 1],
    name: name,
    constituency: constituency,
    party: party,
    party_id: party_id,
    gender: heading.xpath('./following::i').text[/\((.)\)/,1],
    district: box.xpath('.//td[contains(.,"District")]/following-sibling::td').text.strip,
    tel: box.xpath('.//td[contains(.,"Phone")]/following-sibling::td').text.strip,
    # All empty or set to 'None'
      # address: box.xpath('.//td[contains(.,"Postal addrress")]/following-sibling::td').text.strip,
    # All empty:
      # email: box.xpath('.//td[contains(.,"E-mail addrress")]/following-sibling::td').text.strip,
    term: 2014,
    source: url.to_s,
  }
  ScraperWiki.save_sqlite([:id, :term], data)
end

term = {
  id: 2014,
  name: '2014',
  start_date: '2014',
}
ScraperWiki.save_sqlite([:id], term, 'terms')
scrape_list('http://www.parliament.gov.mw/mps.php?mode=alps')

