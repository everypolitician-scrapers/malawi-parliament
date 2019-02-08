#!/bin/env ruby
# frozen_string_literal: true

require 'pry'
require 'scraped'
require 'scraperwiki'

require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

def scraper(pair)
  url, klass = pair.to_a.first
  klass.new(response: Scraped::Request.new(url: url).response)
end

class MembersPage < Scraped::HTML
  field :members do
    noko.css('table.table-striped tbody tr').map { |mp| fragment mp => MemberRow }
  end
end

class MemberName < Scraped::HTML
  field :prefix do
    partitioned.first.join(' ')
  end

  field :name do
    partitioned.last.join(' ')
  end

  field :gender do
    return 'male' if (prefixes & MALE_PREFIXES).any?
    return 'female' if (prefixes & FEMALE_PREFIXES).any?
  end

  private

  FEMALE_PREFIXES  = %w[].freeze
  MALE_PREFIXES    = %w[].freeze
  OTHER_PREFIXES   = %w[dr rev rt hon].freeze
  PREFIXES         = FEMALE_PREFIXES + MALE_PREFIXES + OTHER_PREFIXES

  def partitioned
    words.partition { |w| PREFIXES.include? w.chomp('.').downcase }
  end

  def prefixes
    partitioned.first.map { |w| w.chomp('.') }
  end

  def words
    noko.text.split('|').first.tidy.split(/\s+/)
  end
end

class MemberRow < Scraped::HTML
  field :id do
    name.tr(' ', '-').tr('.', '').downcase
  end

  field :name do
    name_parts.name
  end

  field :honorific_prefix do
    name_parts.prefix
  end

  field :image do
    # NOT relative to this page! This page is transcluded into another one.
    URI.join(url, '/', tds[0].css('img/@src').text).to_s
  end

  field :constituency do
    tds[2].text.tidy
  end

  field :party do
    tds[3].text.tidy
  end

  field :source do
    url
  end

  private

  def tds
    noko.css('td')
  end

  def name_parts
    fragment tds[1] => MemberName
  end
end

starting_url = 'https://www.parliament.gov.mw/views/mp-list.php'
data = scraper(starting_url => MembersPage).members.map(&:to_h)
data.each { |mem| puts mem.reject { |_, v| v.to_s.empty? }.sort_by { |k, _| k }.to_h } if ENV['MORPH_DEBUG']

ScraperWiki.sqliteexecute('DROP TABLE data') rescue nil
ScraperWiki.save_sqlite(%i[id], data)
