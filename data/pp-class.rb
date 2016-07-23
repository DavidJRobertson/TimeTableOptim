#! /usr/bin/env ruby

# pretty print class data

require 'json'

data = JSON.parse(ARGF.read)
data.each do |course|
  puts course['code'] + ' - ' + course['title']
  secs = Hash[course['sections'].group_by{|s| s['type']}.map {|k,v| [k, v.map{|w| w['name']}] }]
  secs.each do |k, v|
    puts "\t#{k}: #{v.join(', ')}"
  end
end
