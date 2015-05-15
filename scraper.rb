#!/bin/env ruby
# encoding: utf-8

require 'scraperwiki'
require 'nokogiri'
require 'date'
require 'open-uri'

require 'colorize'
require 'pry'
require 'csv'
require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'


def noko(url)
  Nokogiri::HTML(open(url).read) 
end

@WIKI = 'http://da.wikipedia.org'

def wikilink(a)
  return '' if a.attr('class') == 'new' 
  @WIKI + a['href']
end

@terms = {
  '1990' => 'Folketingsmedlemmer_valgt_i_1990',
  '1994' => 'Folketingsmedlemmer_valgt_i_1994',
  '1998' => 'Folketingsmedlemmer_valgt_i_1998',
  '2001' => 'Folketingsmedlemmer_valgt_i_2001',
  '2005' => 'Folketingsmedlemmer_valgt_i_2005',
  '2007' => 'Folketingsmedlemmer_valgt_i_2007',
  '2011' => 'Folketingsmedlemmer_valgt_i_2011',
}

@parties = {}

@terms.each do |term, pagename|
  url = "#{@WIKI}/wiki/#{pagename}"
  page = noko(url)
  added = 0

  page.at_css('ul').css('li').each do |party|
    next unless name = party.at_xpath('.//a').text.strip rescue nil
    data = { 
      id: party.text.split(':').first,
      name: name,
    }
    unless @parties.has_key? data[:id]
      puts "New party: #{name}"
      @parties[data[:id]] = name
    end

    ScraperWiki.save_sqlite([:id, :name], data, 'parties') if data[:name]
  end

  page.css('h2 + ul').each do |initial|
    initial.css('li').each do |mem|
      data = { 
        name: mem.at_xpath('.//a').text.strip,
        wikipedia: wikilink(mem.at_xpath('.//a')),
        party_id: (mem.at_xpath('./text()').text.strip)[/\((.*?)\)/, 1],
        # constituency: district,
        source: url,
        term: term,
      }
      next if %w(Indenrigsministeriet Folketinget.dk).include? data[:name]
      raise "No party for #{data[:name]}".red unless data[:party_id]
      data[:wikipedia].prepend @WIKI unless data[:wikipedia].empty?
      # puts data
      added += 1
      ScraperWiki.save_sqlite([:name, :term], data)
    end
  end

  warn "Added #{added} for #{term}"
end

