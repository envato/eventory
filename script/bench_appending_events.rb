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

event_store = Eventory::EventStore.new(database: db)

stream_ids = 200.times.map { SecureRandom.uuid }
TOTAL_EVENTS = 50_000

(1..50).each do |concurrency|
  # puts 'Resetting data'
  db.run 'truncate table events'

  num_events_per_process = TOTAL_EVENTS / concurrency

  db.disconnect

  print "#{concurrency} concurrent processes: "
  start = Time.now

  concurrency.times do
    fork do
      num_events_per_process.times do
        event_store.append_events(stream_ids.sample, Eventory::EventData.new(type: 'test', data: { 'a' => '1' }))
      end
    end
  end
  Process.waitall
  end_time = Time.now
  time_taken = end_time - start

  puts "took #{time_taken} seconds to emit #{num_events_per_process} from #{concurrency} processes"
end
