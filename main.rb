require 'sinatra'
require 'json'
require 'sinatra/json'
require 'sinatra/content_for'

require 'haml'

require_relative 'lib/hash_from_xml'
require_relative 'models'

set :haml, :format => :html5
set :json_encoder, :to_json

helpers do  
  def api_parameters(server, port, path)
    {
      'server'  => server,
      'port'    => port,
      'path'    => path
    }
  end
end

get '/' do
  haml :index
end

post '/api_through_orm' do
  content_type :json
  
  # make API URL
  api_params = api_parameters(request.host, request.port, 'api_stub')
  api_call_model = ApiCallProvider.new(params, api_params)
  begin
    # call stub handler
    response = api_call_model.request
    response[:status] = 'ok'
    puts response

    json response
  rescue RequestValidationError => err
    errs = []
    api_call_model.errors.each_pair { |k, v| errs << { field: k, message: v } }
    
    json status: 'error', errors: errs    
  rescue ApiError => err
    json status: 'error', errors: [{ field: 'API', message: err.message }]
  end
end

get '/api_stub' do
  content_type 'text/xml'
  
  xml = ['<?xml version="1.0" encoding="UTF-8" standalone="no" ?>',
         '<p1:UserData xmlns:p1="urn:exampleuserdata" ' +
         'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" ' +
         'xsi:noNamespaceSchemaLocation="userdata.xsd">',
         '  <firstName>Maurits Cornelis</firstName>',
         '  <lastName>Escher</lastName>',
         '  <age>113</age>',
         '</p1:UserData>'
        ].join("\n")
  
  xml
end
