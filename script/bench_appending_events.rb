require 'eventory'
require 'securerandom'
require 'benchmark'

db = Sequel.connect(adapter: 'postgres',
                    host: '127.0.0.1',
                    database: 'eventory_test')
Sequel.extension(:pg_array_ops)
db.extension(:pg_array)
db.extension(:pg_json)
db.logger = Logger.new(STDOUT) if ENV['LOG']

puts 'Resetting data'
db.run 'truncate table events'

event_store = Eventory::EventStore.new(database: db)

CONCURRENCY = 10
TOTAL_EVENTS = 50_000
EVENTS = TOTAL_EVENTS / CONCURRENCY

stream_ids = 200.times.map { SecureRandom.uuid }

db.disconnect

print "Forking #{CONCURRENCY} processes... "
start = Time.now

CONCURRENCY.times do
  fork do
    EVENTS.times do
      event_store.append(stream_ids.sample, Eventory::EventData.new(type: 'test', data: { 'a' => '1' }))
    end
  end
end
puts 'Done'
Process.waitall
end_time = Time.now
time_taken = end_time - start

puts "Took #{time_taken} to emit #{EVENTS} from #{CONCURRENCY} processes"
