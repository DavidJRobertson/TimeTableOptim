ENV['RACK_ENV'] ||= 'development'

require 'bundler'
Bundler.require :default, ENV['RACK_ENV'].to_sym

require 'pp'
require 'date'

require_relative 'optimizer.rb'


class TimetableOptim < Sinatra::Base
  # Sinatra configuration
  register Sinatra::Contrib
  configure :development do
    register Sinatra::Reloader
    also_reload 'optimizer.rb', 'csp.rb'
  end

  set :root, File.dirname(__FILE__)

  enable :sessions
  enable :logging

  helpers do
    def h(text)
      Rack::Utils.escape_html(text)
    end
  end

  get '/course_search' do
    if params[:q]
      @courses = Course.search params[:q]
    else
      @courses = Course.all
    end

    json @courses
  end


  post '/' do
    session[:course_codes] ||= []

    if params[:add_course]
      c = params[:add_course].upcase
      if !session[:course_codes].include?(c) and Course.list.include?(c)
        session[:course_codes] << c
        session[:course_codes].sort!
      end
    end

    @courses = Course.hash.values_at(*session[:course_codes])

    erb :index
  end

  get '/' do
    session[:course_codes] ||= []

    @courses = Course.hash.values_at(*session[:course_codes])

    erb :index
  end

  get '/clear' do
    session[:course_codes] = []
    if params[:djr]
      session[:course_codes] = ["COMPSCI...??"]
    end

    redirect '/'
  end

  get '/timetable' do
    @courses  = Course.hash.values_at(*session[:course_codes])
    @problem  = TimetablingProblem.new @courses
    @solution = @problem.solve

    @weekcode = params[:week] ? params[:week].to_i : 1
    weekindex = Date.parse('2016-09-19')
    @weekstart = weekindex + ((@weekcode - 1) * 7)

    @weekevents = [
      # 9    10   11   12   13   14   15   16   17
      [nil, nil, nil, nil, nil, nil, nil, nil, nil], # Mon
      [nil, nil, nil, nil, nil, nil, nil, nil, nil], # Tue
      [nil, nil, nil, nil, nil, nil, nil, nil, nil], # Wed
      [nil, nil, nil, nil, nil, nil, nil, nil, nil], # Thu
      [nil, nil, nil, nil, nil, nil, nil, nil, nil]  # Fri
    ]

    if @solution
      @solution.each do |classec, section|
        section.dates.each do |secdate|
          if secdate[0] >= @weekstart and secdate[0] < @weekstart+7
            day = (secdate[0] - @weekstart).to_i
            time = secdate[1]-9
            val = [classec[0], section.name]
            @weekevents[day][time] = val.dup
            @weekevents[day][time] << 1


            prev = @weekevents[day][time-1]
            if prev and prev[0..1] == val
              @weekevents[day][time] << :continued

              l = 1
              while @weekevents[day][time-l] and @weekevents[day][time-l][0..1] == val
                l += 1
              end
              @weekevents[day][time-l+1][2] = l
            end

          end
        end
      end
    end

    erb :timetable
  end

end
