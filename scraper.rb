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

def scrape_list(url)
  noko = noko_for(url)
  h2 = noko.xpath('//h2[span[@id="Election_results"]]')
  governates = h2.xpath('following-sibling::h2 | following-sibling::h3').slice_before { |e| e.name == 'h2' }.first
  governates.each do |governate|
    area = governate.css('span.mw-headline').text
    tables = governate.xpath('following-sibling::table | following-sibling::h3 | following-sibling::h2').slice_before { |e| e.name != 'table' }.first

    tables.each do |table|
      data = table.xpath('.//tr[td]').map do |tr|
        tds = tr.css('td')
        if area.include? 'Quota'
          {
            name:     tds[0].text.tidy,
            wikiname: tds[0].xpath('.//a[not(@class="new")]/@title').text,
            area:     tds[3].text.tidy,
            party:    tds[1].text.tidy,
            type:     'Woman',
          }
        elsif area == 'National List'
          tds[2].text.split(/,\s*/).map do |name|
            {
              name:  name.tidy,
              area:  'National List',
              type:  'National List',
              party: tds[0].text.tidy,
            }
          end
        else
          {
            name:     tds[0].text.tidy,
            wikiname: tds[0].xpath('.//a[not(@class="new")]/@title').text,
            area:     area,
            party:    tds[1].text.tidy,
            type:     tds[2].text.tidy,
          }
        end
      end

      data.flatten.each do |p|
        entry = p.merge(term: '2013', source: url)
        entry[:party] = 'Independent' if entry[:party].to_s.empty?
        entry[:area].sub!(' Governorate', '') if entry[:area].include? 'Governorate'
        puts entry.reject { |_, v| v.to_s.empty? }.sort_by { |k, _| k }.to_h if ENV['MORPH_DEBUG']
        ScraperWiki.save_sqlite(%i(name area type), entry)
      end
    end
  end
end

ScraperWiki.sqliteexecute('DELETE FROM data') rescue nil
scrape_list('https://en.wikipedia.org/wiki/Jordanian_parliamentary_election_results,_2013')
