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


def noko_for(url)
  Nokogiri::HTML(open(url).read) 
end

@BASE = 'https://da.wikipedia.org'

def wikilink(a)
  return if a.attr('class') == 'new' 

  @BASE + a['href']
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

def party_hash(noko, table_type)

  if table_type == 'table'
    return Hash[noko.xpath('//table[.//th[.="Partinavn"]]//tr[td]').map { |tr| tr.css('td').take(2).map(&:text) }]
  end

  return Hash[
    noko.at_css('ul').css('li').map do |party|
      next unless name = party.at_xpath('.//a').text.strip rescue nil
      [ party.text.split(':').first, name ]
    end.compact
  ]
end



@terms.reverse_each do |term, pagename|
  url = "#{@BASE}/wiki/#{pagename}"
  page = noko_for(url)
  added = 0

  party_layout = term == '2011' ? 'table' : 'list'
  parties = party_hash(page, party_layout)

  page.css('h2 + ul').each do |initial|
    break if initial.xpath('preceding::h2').last.text.include? 'Eksterne henvisninger'
    initial.css('li').each do |mem|
      next if mem.attr('class') == 'mw-empty-li'
      data = { 
        name: mem.at_xpath('.//a').text.strip,
        party_id: (mem.at_xpath('./text()').text.strip)[/\((.*?)\)/, 1],
        # constituency: district,
        wikiname: mem.xpath('.//a[not(@class="new")]/@title').map(&:text).first,
        term: term,
      } rescue binding.pry
      next if %w(Indenrigsministeriet Folketinget.dk).include? data[:name]
      raise "No party for #{data[:name]}".red unless data[:party_id]
      data[:party] = parties[ data[:party_id] ]
      added += 1
      ScraperWiki.save_sqlite([:name, :term], data)
    end
  end

  puts "Added #{added} for #{term}"
end

