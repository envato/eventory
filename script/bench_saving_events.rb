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

db.run 'truncate table events'
#db.run 'update event_counter set number = 0'

event_store = Eventory::EventStore.new(database: db)

CONCURRENCY = 5
EVENTS = 10_000

stream_ids = 10.times.map { SecureRandom.uuid }

db.disconnect

start = Time.now

CONCURRENCY.times do
  fork do
    EVENTS.times do
      event_store.save(stream_ids.sample, Eventory::EventData.new(type: 'test', data: { 'a' => '1' }))
    end
  end
end
Process.waitall
end_time = Time.now
time_taken = end_time - start

puts "Took #{time_taken} to emit #{EVENTS} from #{CONCURRENCY} processes"
