require 'logger'
require 'pry'
require 'database_cleaner'

module DatabaseHelpers
  def database
    $db
  end
end

RSpec.configure do |config|
  config.include DatabaseHelpers

  config.before(:suite) do
    $db = Sequel.connect(adapter: 'postgres',
                         host: '127.0.0.1',
                         database: 'postgres_event_store_test')
    $db.extension(:pg_json)
    $db.logger = Logger.new(STDOUT) if ENV['LOG']

    DatabaseCleaner[:sequel].db = $db
    DatabaseCleaner[:sequel].clean_with(:truncation)
    $db[:event_counter].insert(number: 0)
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
