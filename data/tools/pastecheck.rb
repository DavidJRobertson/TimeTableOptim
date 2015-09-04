#! /usr/bin/env ruby

require 'json'

if STDIN.tty?
  puts "./pastecheck.rb < file.json"
  exit
end

data = JSON.parse(STDIN.read)
data.each do |course|
  puts course['code'] + ' - ' + course['title']
  secs = Hash[course['sections'].group_by{|s| s['type']}.map {|k,v| [k, v.map{|w| w['name']}] }]
  secs.each do |k, v|
    puts "\t#{k}: #{v.join(', ')}"
  end
end
