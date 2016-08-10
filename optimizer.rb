#! /usr/bin/env ruby

require 'date'
require 'json'
require_relative 'csp'

SEM1_START = Date.parse("2016-09-19")
SEM2_START = Date.parse("2017-01-09")

class Section
  def initialize(data, course)
    @course = course
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
  attr_reader :course, :type, :name, :dates, :earliest_start, :status
  def conflicts_with?(other)
    (@dates & other.dates).length > 0
  end

  def ndates
    sem1_start = Date.parse("2016-09-19")
    @dates.map do |d|
      [(d[0]-sem1_start).to_i, d[1]]
    end
  end

  def to_json(options=nil)
    {'course' => @course, 'type' => @type, 'name' => @name, 'status' => @status, 'dates' => ndates}.to_json
  end
end

class Course
  @@courses = {}
  def self.load_file(path)
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



  def initialize(data)
    @code  = data['code']
    @title = data['title']
    @sections = data['sections'].reject { |s| s['type'] == 'Admin' }.map { |sd| Section.new(sd, @code) }

    @sections_by_type = {}

    @sections.each do |section|
      if not @sections_by_type.has_key? section.type
        @sections_by_type[section.type] = []
      end
      @sections_by_type[section.type] << section
    end
  end
  attr_reader :code, :title, :sections, :sections_by_type

  def to_json(options=nil)
    {'code' => @code, 'title' => @title}.to_json
  end
end

class TimetablingProblem < CSP
  def initialize(courses)
    super()
    @courses = courses

    @courses.each do |course|
      course.sections_by_type.keys.each do |section_type|
        var([course.code, section_type], course.sections_by_type[section_type])
      end
    end

    all_pairs(@vars.keys)  { |a, b| !a.conflicts_with?(b) }

    @ban_times = [
      [], # Sun
      [], # Mon
      [], # Tue
      [], # Wed
      [], # Thu
      [], # Fri
      [], # Sat
    ]

    @already_have = [
      #[["COMPSCI 2005", "Lecture"],  "LC01"]
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
end

Course.load_file("./data/class-data.json")

if __FILE__ == $0
  courses = JSON.parse(File.read('./data/djr.json')).map { |cd| Course.new(cd) }
  problem = TimetablingProblem.new(courses)
  solution = problem.solve
  puts problem.print(solution)
end
