require 'sinatra'
require 'json'
require 'sinatra/json'
require 'sinatra/content_for'

require 'haml'

require 'net/http'

require_relative 'models'

set :haml, :format => :html5
set :json_encoder, :to_json

helpers do
  def make_api_call(server, port, path, api_model)
    url = "http://#{server}:#{port}/#{path}"
    puts url
    # close connection after call by API server automatically
    headers = { 'Connection' => 'close' }
    
    request = Net::HTTP::Get.new(url, headers)
    resp = Net::HTTP.start(server, port) do |api|
      api.request(request)
    end
    
    JSON.parse(resp.body)
  end
end

get '/' do
  haml :index
end

post '/api_through_orm' do
  content_type :json
  
  api_call_model = ApiCallProvider.new(params)
  if api_call_model.valid?
    # call stub handler
    json make_api_call(request.host, request.port, 'api_stub', api_call_model)
  else
    errs = []
    api_call_model.errors.each_pair { |k, v| errs << { field: k, message: v } }
    
    json status: 'error', errors: errs
  end
end

get '/api_stub' do
  content_type :json
  
  json status: 'ok' 
end
