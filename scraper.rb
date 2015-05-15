#!/bin/env ruby
# encoding: utf-8

require 'scraperwiki'
require 'nokogiri'
require 'date'
require 'open-uri'

require 'open-uri/cached'
require 'colorize'
require 'pry'
require 'csv'

def noko(url)
  Nokogiri::HTML(open(url).read) 
end

@WIKI = 'http://da.wikipedia.org'

def wikilink(a)
  return if a.attr('class') == 'new' 
  @WIKI + a['href']
end

@terms = {
  '1990' => 'Folketingsmedlemmer_valgt_i_1990',
  # '1994' => 'Folketingsmedlemmer_valgt_i_1994',
  # '1998' => 'Folketingsmedlemmer_valgt_i_1998',
  # '2001' => 'Folketingsmedlemmer_valgt_i_2001',
  # '2005' => 'Folketingsmedlemmer_valgt_i_2005',
  # '2007' => 'Folketingsmedlemmer_valgt_i_2007',
  # '2011' => 'Folketingsmedlemmer_valgt_i_2011',
}

@terms.each do |term, pagename|
  url = "#{@WIKI}/wiki/#{pagename}"
  page = noko(url)
  added = 0

  page.css('h2 + ul').each do |initial|
    initial.css('li').each do |mem|
      data = { 
        name: mem.at_xpath('a').text.strip,
        wikipedia: mem.xpath('a[not(@class="new")]/@href').text.strip,
        party: (mem.xpath('./text()').text.strip)[/\((.*?)\)/, 1],
        # constituency: district,
        source: url,
        term: term,
      }
      unless data[:party]
        warn "No party for #{data[:name]}".red
        next
      end
      data[:wikipedia].prepend @WIKI unless data[:wikipedia].empty?
      puts data
      added += 1
      # ScraperWiki.save_sqlite([:name, :term], data)
    end
  end

  warn "Added #{added} for #{term}"
end

