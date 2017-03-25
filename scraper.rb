#!/bin/env ruby
# encoding: utf-8
# frozen_string_literal: true

require 'pry'
require 'scraped'
require 'scraperwiki'

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
  '2015' => 'Folketingsmedlemmer_valgt_i_2015',
}

@parties = {}

def party_hash(noko, table_type)
  if table_type == 'table'
    return Hash[noko.xpath('//table[.//th[.="Partinavn"]]//tr[td]').map { |tr| tr.css('td').take(2).map(&:text) }]
  end

  Hash[
    noko.at_css('ul').css('li').map do |party|
      next unless name = party.at_xpath('.//a').text.tidy rescue nil
      [party.text.split(':').first, name]
    end.compact
  ]
end

MONTH = %w(nil januar februar marts april maj juni juli august september oktober november december).freeze
def date_from(text)
  matched = text.match(/(\d+)\.?\s+(\w+)\s+(\d{4})/)
  unless matched
    warn "Can't find date in #{text}"
    return
  end
  d, m, y = matched.captures
  '%d-%02d-%02d' % [y, MONTH.find_index(m), d]
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
      next if mem.attr('class') == 'mw-empty-li' || mem.attr('class') == 'mw-empty-elt'
      data = {
        name:     mem.at_xpath('.//a').text.tidy,
        party_id: mem.at_xpath('./text()').text.tidy[/\((.*?)\)/, 1],
        # constituency: district,
        wikiname: mem.xpath('.//a[not(@class="new")]/@title').map(&:text).first,
        term:     term,
      }
      next if %w(Indenrigsministeriet Folketinget.dk).include? data[:name]
      raise "No party for #{data[:name]}".red unless data[:party_id]
      data[:party] = parties[data[:party_id]]

      data[:end_date] = date_from(mem.text) if mem.text.include?('Udtrådt') || mem.text.include?('indtil')
      data[:start_date] = date_from(mem.text) if mem.text.include?('Overtog')

      added += 1
      ScraperWiki.save_sqlite(%i(name term), data)
    end
  end

  puts "Added #{added} for #{term}"
end
