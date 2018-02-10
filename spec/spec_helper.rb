require "bundler/setup"
require "postgres_event_store"
require 'pry'
require 'securerandom'

Dir.glob(File.dirname(__FILE__) + '/support/**/*.rb') { |f| require f }

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
