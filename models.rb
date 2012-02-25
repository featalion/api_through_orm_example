require 'data_mapper'
require 'net/http'
require 'nokogiri'
require 'uri'
require 'digest/sha1'

#
# If you need to use another default DB
#
# DataMapper.setup(:default, DB_STR)
# DataMapper.setup(:abstract, 'abstract::')
#
# And add the following code to all provider classes
#
# def self.default_repository_name
#   :abstract
# end
#

DataMapper.setup(:default, 'abstract::')

class RequestValidationError < StandardError
end

class ApiError < StandardError
end

class ApiCallProvider
  include DataMapper::Resource
  
  property :id, Serial
  # DataMapper does not work right with local URLs like 'http://localhost:4567/path'
  # Enable it in real life ;)
  property :api_url, String, :required => true #, :format => :url
  property :email, String, :required => true, :format => :email_address
  property :password, String, :required => true
  
  #
  # Initialize API provider
  #
  # attrs: standard attributes for DM
  #
  # api_params: API parameters Hash
  #   'server' => required
  #   'port'   => required
  #   'path'   => required
  #
  # headers: optional headers for API request
  #   'Connection' => 'close' (default, to close connection on API side)
  #
  def initialize(attrs, api_params, headers = {})
    # Check API parameters hash
    raise "API parameters must be Hash" unless api_params.kind_of? Hash
    ['server', 'port', 'path'].each do |param_name|
      unless api_params[param_name]
        raise "'#{param_name}' is not defined in API parameters hash"
      end
    end

    @server = api_params['server']
    @port   = api_params['port']
      
    @headers = if headers.kind_of? Hash
      { 'Connection' => 'close' }.merge!(headers)
    else
      { 'Connection' => 'close' }
    end
    
    super attrs.merge({ 'api_url' => make_api_url(api_params) })
  end
  
  def request
    raise RequestValidationError, "Not Valid" unless self.valid?
    
    request = Net::HTTP::Get.new(api_uri(), @headers)
    resp = Net::HTTP.start(@server, @port) do |api|
      api.request(request)
    end

    process_api_response(resp)
  end
  
  
  private
  
  def make_api_url(params)
    "http://#{params['server']}:#{params['port']}/#{params['path']}"
  end
  
  def process_api_response(resp)
    doc = Nokogiri::XML(resp.body)

    schema = Nokogiri::XML.Schema( File.open("xsd/userdata.xsd") )
    errors = schema.validate doc
    # validation errors (by XSD)
    unless errors.empty?
      puts "WARNING: Xml doesn't match userdata.xsd"
      puts errors.join("\n")
    end

    # error from the API
    error = doc.xpath('//errorMessage')
    raise ApiError, error.to_s unless error.nil? or error.empty?

    ud = nil
    begin
      # parse XML response string to hash
      ud = Hash.from_xml(resp.body)
      # remove attributes (like :noNamespaceSchemaLocation)
      # see xsd/userdata.xsd for schema
      ud[:UserData].delete(:attributes)
    rescue XmlParseError => err
      raise ApiError, "Responsed with wrong XML"
    end
    
    ud
  end
  
  def api_uri
    uri = self.api_url +
          "?email=" +
          URI.escape(self.email, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]")) +
          "&password=" +
          URI.escape(Digest::SHA1.hexdigest(self.password),
                     Regexp.new("[^#{URI::PATTERN::UNRESERVED}]")
          )
    uri
  end
  
end

DataMapper.finalize
DataMapper.auto_upgrade!
