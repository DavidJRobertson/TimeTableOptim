#! /usr/bin/env ruby
require 'pp'
require 'date'
require 'json'
require './csp'


class Section
  def initialize(data)
    @type = data['type']
    @name = data['name']
    @dates_data = data['dates']
    @dates = []
    @earliest_start = 23
    day_codes = {'Su' => 0, 'Mo' => 1, 'Tu' => 2, 'We' => 3, 'Th' => 4, 'Fr' => 5, 'Sa' => 6}
    @dates_data.each do |dd|
      start_date, end_date = dd['period'].split(' - ').map {|d| Date.new(* d.split('/').reverse.map{|i| i.to_i})}
      day   = day_codes[dd['times'][0..1]]
      times =  (dd['times'][4..5].to_i .. dd['times'][12..13].to_i).to_a[0...-1]
      @earliest_start = (times[0] < @earliest_start) ? times[0] : @earliest_start
      days = (start_date .. end_date).select { |d| d.wday == day }
      dts = days.product(times)
      @dates.concat dts
    end
  end
  attr_reader :type, :name, :dates, :earliest_start
  def conflicts_with?(other)
    (@dates & other.dates).length > 0
  end
end
class Course
  def initialize(data)
    @code  = data['code']
    @title = data['title']
    @sections = data['sections'].reject { |s| s['type'] == 'Admin' }.map { |sd| Section.new(sd) }

    @lecture_sections  = []
    @tutorial_sections = []
    @lab_sections      = []

    @sections.each do |section|
      case section.type
      when 'Lecture'
        @lecture_sections  << section
      when 'Tutorial'
        @tutorial_sections << section
      when 'Laboratory'
        @lab_sections      << section
      end
    end
  end
  attr_reader :code, :title, :sections, :lecture_sections, :tutorial_sections, :lab_sections
end

class TimetablingProblem < CSP
  def initialize(file)
    super()
    @courses = JSON.parse(File.read('./data/djr.json')).map { |cd| Course.new(cd) }

    @courses.each do |course|
      var([course.code, :lecture],  course.lecture_sections)  unless course.lecture_sections.empty?
      var([course.code, :tutorial], course.tutorial_sections) unless course.tutorial_sections.empty?
      var([course.code, :lab],      course.lab_sections)      unless course.lab_sections.empty?
    end

    all_pairs(@vars.keys)  { |a, b| !a.conflicts_with?(b) }

    #@vars.keys.each do |key|
    #  constrain(key) do |section|
    #    !section.dates.any? {|d|  (d[0].wday == 4) and d[1] < 11}
    #  end
    #end

  end
  attr_reader :courses

  def print!(solution)
    if solution
      soltree = Hash[solution.keys.group_by { |c| c.first }.map { |k, v| [k, v.map {|w| w.last}] }]
      soltree.keys.sort.each do |course|
        title = @courses.find { |c| c.code == course }.title

        puts course + " - " + title
        soltree[course].each do |section|
          fill = (section == :lab) ? ":\t\t" : ":\t"
          puts "\t" + section.to_s.capitalize + fill + solution[[course, section]].name
        end
        puts
      end
    else
      puts "No solution found."
    end
  end
  def print_concise!(solution)
    if solution
      solution.keys.sort.each do |key|
        puts key.first + ' ' + key.last.to_s.capitalize + ' => ' + solution[key].name
      end
    else
      puts "No solution found."
    end
  end
end

problem = TimetablingProblem.new('./data/djr.json')
solution = problem.solve
#problem.print_concise!(solution)
problem.print!(solution)
