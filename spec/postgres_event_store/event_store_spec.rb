RSpec.describe PostgresEventStore::EventStore do
  subject(:event_store) { described_class.new(database: database) }
  let(:stream_id) { SecureRandom.uuid }

  it 'saves an event' do
    event_id = SecureRandom.uuid
    event_store.save(stream_id, PostgresEventStore::EventData.new(type: 'test', data: { a: 'b' }, id: event_id))
    events = database[:events].all
    expect(events.count).to eq 1
    event = events[0]
    aggregate_failures do
      expect(event[:number]).to eq 1
      expect(event[:stream_id]).to eq stream_id
      expect(event[:stream_version]).to eq 1
      expect(event[:type]).to eq 'test'
      expect(event[:data]).to eq('a' => 'b')
      expect(event[:id]).to eq event_id
      expect(event[:recorded_at]).to be_an_instance_of(Time)
    end
  end

  it 'saves multiple typed events' do
    event_store.save(stream_id, ItemAdded.new(item_id: 1, name: 'test'))
    event_store.save(stream_id, ItemRemoved.new(item_id: 1))
    events = database[:events].all
    expect(events.count).to eq 2
    event_1 = events[0]
    event_2 = events[1]
    aggregate_failures do
      expect(event_1[:number]).to eq 1
      expect(event_1[:stream_id]).to eq stream_id
      expect(event_1[:stream_version]).to eq 1
      expect(event_1[:type]).to eq 'ItemAdded'
      expect(event_1[:data]).to eq('item_id' => 1, 'name' => 'test')
      expect(event_1[:id]).to be_an_instance_of(String)
      expect(event_1[:recorded_at]).to be_an_instance_of(Time)

      expect(event_2[:number]).to eq 2
      expect(event_2[:stream_id]).to eq stream_id
      expect(event_2[:stream_version]).to eq 2
      expect(event_2[:type]).to eq 'ItemRemoved'
      expect(event_2[:data]).to eq('item_id' => 1)
      expect(event_2[:id]).to be_an_instance_of(String)
      expect(event_2[:recorded_at]).to be_an_instance_of(Time)
    end
  end

  it 'saves multiple events' do
    event_store.save(stream_id, PostgresEventStore::EventData.new(type: 'test', data: {a: 'b'}))
    event_store.save(stream_id, PostgresEventStore::EventData.new(type: 'test2', data: {c: 'd'}))
    events = database[:events].all
    expect(events.count).to eq 2
    event_1 = events[0]
    event_2 = events[1]
    aggregate_failures do
      expect(event_1[:number]).to eq 1
      expect(event_1[:stream_id]).to eq stream_id
      expect(event_1[:stream_version]).to eq 1
      expect(event_1[:type]).to eq 'test'
      expect(event_1[:data]).to eq('a' => 'b')
      expect(event_1[:id]).to be_an_instance_of(String)
      expect(event_1[:recorded_at]).to be_an_instance_of(Time)

      expect(event_2[:number]).to eq 2
      expect(event_2[:stream_id]).to eq stream_id
      expect(event_2[:stream_version]).to eq 2
      expect(event_2[:type]).to eq 'test2'
      expect(event_2[:data]).to eq('c' => 'd')
      expect(event_2[:id]).to be_an_instance_of(String)
      expect(event_2[:recorded_at]).to be_an_instance_of(Time)
    end
  end

  it "doesn't increment the number number if the transaction is aborted" do
    tmp_db = DatabaseHelpers.connect_database
    long_type_name = 't' * 256
    begin
      expect {
        PostgresEventStore::EventStore.new(database: tmp_db)
          .save(stream_id, PostgresEventStore::EventData.new(type: long_type_name, data: {}))
      }.to raise_error(Sequel::DatabaseError)
      expect(database[:events].count).to eq 0
      event_store.save(stream_id, PostgresEventStore::EventData.new(type: 'test', data: {}))
      expect(database[:events].map {|e| e[:number]}).to eq([1])
    ensure
      tmp_db.disconnect
    end
  end
end
