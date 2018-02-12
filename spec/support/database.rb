require 'logger'
require 'pry'
require 'database_cleaner'

module DatabaseHelpers
  def database
    $db
  end

  def self.connect_database
    db = Sequel.connect(adapter: 'postgres',
                         host: '127.0.0.1',
                         database: 'postgres_event_store_test')
    Sequel.extension(:pg_array_ops)
    db.extension(:pg_array)
    db.extension(:pg_json)
    db.logger = Logger.new(STDOUT) if ENV['LOG']
    db
  end
end

RSpec.configure do |config|
  config.include DatabaseHelpers

  config.before(:suite) do
    $db = DatabaseHelpers.connect_database

    DatabaseCleaner[:sequel].db = $db
    DatabaseCleaner[:sequel].clean_with(:truncation, except: %w[ event_counter ])
    $db[:event_counter].update(number: 0)
  end

  config.before(:each) do |example|
    unless example.metadata[:skip_db_clean]
      DatabaseCleaner[:sequel].strategy = :transaction
      DatabaseCleaner[:sequel].start
    end
  end

  config.after(:each) do |example|
    unless example.metadata[:skip_db_clean]
      DatabaseCleaner[:sequel].clean
    end
  end
end
