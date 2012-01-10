require 'data_mapper'

#
# If you need to use another default DB
#
# DataMapper.setup(:default, DB_STR)
# DataMapper.setup(:abstract, 'abstract::')
#
# and add the following code to all provider classes
#
# def self.default_repository_name
#   :abstract
# end
#

DataMapper.setup(:default, 'abstract::')

class ApiCallProvider
  include DataMapper::Resource
  
  property :id, Serial
  property :email, String, :required => true, :format => :email_address
  property :password, String, :required => true
  
end

DataMapper.finalize
DataMapper.auto_upgrade!
