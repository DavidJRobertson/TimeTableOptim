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
  enable :logging
  helpers do
    def h(text)
      Rack::Utils.escape_html(text)
    end
  end

  ################

  get '/' do
    # Render the HTML [single-page JS app]
    erb :index
  end

  get '/course_search' do
    # Endpoint for the autocomplete box
    json (params[:q] ? Course.search(params[:q]) : Course.all)
  end

  post '/solve' do
    # Endpoint to solve the TSP
    @courses  = Course.hash.values_at(*params["courses"].uniq)
    @problem  = TimetablingProblem.new @courses
    @solution = @problem.solve

    json({
      "start_dates" => {
        "semester_1": "2016-09-19",
        "semester_2": "2017-01-09"
      },
      "courses"  => @courses.map{|c| {c.code => c.title} }.inject(:merge),
      "sections" => (@solution ? @solution.values : nil),
      "printout" => @problem.print(@solution)
    })
  end
end
