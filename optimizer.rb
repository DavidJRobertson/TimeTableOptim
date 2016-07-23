#! /usr/bin/env ruby

require 'date'
require 'json'
require_relative 'csp'

class Section
  def initialize(data)
    @type   = data['type']
    @name   = data['name']
    @status = data['status']
    @dates = []
    @earliest_start = 23
    day_codes = {'Su' => 0, 'Mo' => 1, 'Tu' => 2, 'We' => 3, 'Th' => 4, 'Fr' => 5, 'Sa' => 6}
    data['dates'].each do |dd|
      if dd['period'] == "TBA" or dd['times'] == "TBA"
        next
      end
      start_date, end_date = dd['period'].split(' - ').map {|d| Date.new(* d.split('/').reverse.map{|i| i.to_i})}
      day   = day_codes[dd['times'][0..1]]
      times =  (dd['times'][4..5].to_i .. dd['times'][12..13].to_i).to_a[0...-1]
      @earliest_start = ((times[0] < @earliest_start) ? times[0] : @earliest_start) unless times.empty?
      days = (start_date .. end_date).select { |d| d.wday == day }
      dts = days.product(times)
      @dates.concat dts
    end
  end
  attr_reader :type, :name, :dates, :earliest_start, :status
  def conflicts_with?(other)
    (@dates & other.dates).length > 0
  end
end
class Course
  @@courses = {}
  def self.load_file(file)
    path = File.expand_path("../data/#{file}", __FILE__)
    data = JSON.parse(File.read(path))
    data.each { |cd| @@courses[cd['code']] = Course.new(cd) }
  end
  def self.all
    @@courses.values
  end
  def self.list
    @@courses.keys
  end
  def self.hash
    @@courses
  end
  def self.search(query)
    q = query.downcase
    @@courses.values.select do |course|
      course.code.downcase.include?(q) or
      course.title.downcase.include?(q)
    end
  end

  def to_json(options=nil)
    {'code' => @code, 'title' => @title}.to_json
  end

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
  def initialize(courses)
    super()
    @courses = courses

    @courses.each do |course|
      var([course.code, :lecture],  course.lecture_sections)  unless course.lecture_sections.empty?
      var([course.code, :tutorial], course.tutorial_sections) unless course.tutorial_sections.empty?
      var([course.code, :lab],      course.lab_sections)      unless course.lab_sections.empty?
    end

    all_pairs(@vars.keys)  { |a, b| !a.conflicts_with?(b) }

    @ban_times = [
      [], # Sun
      [12,13,17], # Mon
      [17], # Tue
      [17], # Wed
      [17], # Thu
      [17], # Fri
      [], # Sat
    ]

    @already_have = [
      [["COMPSCI 2005", :lecture],  "LC01"],
      [["COMPSCI 2005", :tutorial], "TU01"],
      [["COMPSCI 2005", :lab],      "LB01"],

      [["COMPSCI 2007", :lecture],  "LC01"],
      [["COMPSCI 2007", :lab],      "LB09"],

      [["COMPSCI 2005", :lecture],  "LC01"],
      [["COMPSCI 2005", :tutorial], "TU01"],
      [["COMPSCI 2005", :lab],      "LB01"],

      [["COMPSCI 2020", :lecture],  "LC01"],
      [["COMPSCI 2020", :tutorial], "TU01"],
      [["COMPSCI 2020", :lab],      "LB05"],

      [["COMPSCI 2021", :lecture],  "LC01"],
      [["COMPSCI 2021", :lab],      "LB06"],

      [["ENG 2004", :lecture],  "LC01"],
      [["ENG 2004", :lab],      "LB03"],

      [["ENG 2020", :lecture],  "LC01"],
      [["ENG 2020", :lab],      "LB01"],

      [["ENG 2023", :lecture],  "LC01"],
      [["ENG 2023", :lab],      "LB01"],

      [["ENG 2025", :lecture],  "LC01"],
      [["ENG 2025", :lab],      "LB02"],

      [["ENG 2029", :lecture],  "LC01"],
      [["ENG 2029", :lab],      "LB02"],

      [["ENG 2086", :lecture],  "LC01"],
      [["ENG 2086", :tutorial], "TU01"],

    ]


    @vars.keys.each do |key|
      constrain(key) { |section| section.status == "Open" or @already_have.include?([key, section.name]) }
      constrain(key) do |section|
        !section.dates.any? {|d| @ban_times[d[0].wday].include? d[1] }
      end
    end
  end
  attr_reader :courses, :ban_times

  def print(solution)
    res = ""
    if solution
      soltree = Hash[solution.keys.group_by { |c| c.first }.map { |k, v| [k, v.map {|w| w.last}] }]
      soltree.keys.sort.each do |course|
        title = @courses.find { |c| c.code == course }.title

        res += course + " - " + title + "\n"
        soltree[course].each do |section|
          fill = (section == :lab) ? ":\t\t" : ":\t"
          res += "\t" + section.to_s.capitalize + fill + solution[[course, section]].name + "\n"
        end
        res += "\n"
      end
    else
      res += "No solution found.\n"
    end
    return res
  end
  def print!(solution)
    puts print(solution)
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

#Course.load_file('djr.json')
Course.load_file('eng.json')
Course.load_file('cs.json')

if __FILE__ == $0
  courses = JSON.parse(File.read('./data/djr.json')).map { |cd| Course.new(cd) }
  problem = TimetablingProblem.new(courses)
  solution = problem.solve
  #problem.print_concise!(solution)
  problem.print!(solution)
end
