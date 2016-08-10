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
    # Endpoint to solve the CSP
    params["courses"].uniq!
    @courses  = Course.hash.values_at(*params["courses"])

    invalid = []
    @courses.each_with_index { |v, i| invalid << params["courses"][i] if v.nil? }
    if not invalid.empty?
      status 400
      return json({error: { id: "invalid_course", invalid_courses: invalid, message: "Unrecognised course: "+invalid.join(", ") }})
    end

    @problem  = TimetablingProblem.new(@courses)
    @solution = @problem.solve

    json({
      "start_dates" => {
        "semester_1": SEM1_START,
        "semester_2": SEM2_START
      },
      "courses"  => @courses.map{|c| {c.code => c.title} }.inject(:merge),
      "sections" => (@solution ? @solution.values : nil),
      "printout" => @problem.print(@solution)
    })
  end
end
