#! /usr/bin/env ruby

require 'json'

engdata = JSON.parse(File.read('eng.json'))
csdata  = JSON.parse(File.read('cs.json'))
data = engdata + csdata

courses = [
  'COMPSCI 2007',
  'COMPSCI 2020',
  'COMPSCI 2021',
  'COMPSCI 2005',
  'ENG 2004',
  'ENG 2020',
  'ENG 2023',
  'ENG 2025',
  'ENG 2029',
  'ENG 2086'
]


filtered = data.select { |c| courses.include?(c['code']) }

File.open('djr.json', 'w') { |file| file.write(JSON.pretty_generate(filtered)) }
