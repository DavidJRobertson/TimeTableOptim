require 'rack'
require 'rack/contrib'

require File.dirname(__FILE__) + '/app'

use Rack::BounceFavicon
use Rack::PostBodyContentTypeParser


run TimetableOptim
