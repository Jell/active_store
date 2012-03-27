require 'active_store'

RSpec.configure do |config|
  config.before(:each) do
    ActiveStore::Base.connection_string = nil
    ActiveStore::Base.connection.flush_all
  end
end

