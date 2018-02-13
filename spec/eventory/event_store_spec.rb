RSpec.describe Eventory::EventStore do
  subject(:event_store) { described_class.new(database: database) }
  let(:stream_id) { SecureRandom.uuid }

  describe '#save' do
    it 'saves an event' do
      event_id = SecureRandom.uuid
      event_store.save(stream_id, Eventory::EventData.new(type: 'test', data: { a: 'b' }, id: event_id))
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
      event_store.save(stream_id, [ItemAdded.new(item_id: 1, name: 'test'), ItemRemoved.new(item_id: 1)])
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
      event_store.save(stream_id, [Eventory::EventData.new(type: 'test', data: {a: 'b'}), Eventory::EventData.new(type: 'test2', data: {c: 'd'})])
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
          Eventory::EventStore.new(database: tmp_db)
            .save(stream_id, Eventory::EventData.new(type: long_type_name, data: {}))
        }.to raise_error(Sequel::DatabaseError)
        expect(database[:events].count).to eq 0
        event_store.save(stream_id, Eventory::EventData.new(type: 'test', data: {}))
        expect(database[:events].map {|e| e[:number]}).to eq([1])
      ensure
        tmp_db.disconnect
      end
    end

    context 'optimistic locking' do
      let(:event) { Eventory::EventData.new(type: 'test', data: { a: 'b' }) }
      let(:event_2) { Eventory::EventData.new(type: 'test', data: { a: 'c' }) }

      context "when the stream doesn't exist" do
        it 'saves the event if the version is correct' do
          event_store.save(stream_id, event, expected_version: 0)
        end

        it 'raises a concurrency error if the version is incorrect' do
          expect {
            event_store.save(stream_id, event, expected_version: 1)
          }.to raise_error(Eventory::ConcurrencyError)
        end
      end

      context 'when the stream exists' do
        before { event_store.save(stream_id, event_2) }

        it 'saves the event if the version is correct' do
          event_store.save(stream_id, event, expected_version: 1)
        end

        it 'raises a concurrency error if the version is incorrect' do
          expect {
            event_store.save(stream_id, event, expected_version: 2)
          }.to raise_error(Eventory::ConcurrencyError)
        end
      end
    end
  end

  context 'reading events' do
    let(:event) { Eventory::EventData.new(type: 'test', data: { a: 'b' }, id: SecureRandom.uuid) }
    let(:event_2) { ItemRemoved.new(item_id: 1) }
    let(:event_3) { ItemAdded.new(item_id: 1, name: 'Test') }
    let(:stream_id_2) { SecureRandom.uuid }

    before do
      event_store.save(stream_id, event)
      event_store.save(stream_id, event_2)
      event_store.save(stream_id_2, event_3)
    end

    describe '#read_all_events_from' do
      it 'reads events in order' do
        events = event_store.read_all_events_from(1)
        expect(events.map(&:number)).to eq [1, 2, 3]
      end

      it 'has correct event uuids' do
        events = event_store.read_all_events_from(1)
        expect(events[0].id).to eq event.id
      end

      it 'hydrates event types to the appropriate classes' do
        events = event_store.read_all_events_from(1)
        expect(events[0].data.class).to eq Hash
        expect(events[1].data.class).to eq ItemRemoved
        expect(events[2].data.class).to eq ItemAdded
      end

      it 'has the correct event number' do
        events = event_store.read_all_events_from(1)
        expect(events[0].number).to eq 1
        expect(events[1].number).to eq 2
        expect(events[2].number).to eq 3
      end

      it 'has the correct stream_id' do
        events = event_store.read_all_events_from(1)
        expect(events[0].stream_id).to eq stream_id
        expect(events[1].stream_id).to eq stream_id
        expect(events[2].stream_id).to eq stream_id_2
      end

      it 'has the correct stream_version' do
        events = event_store.read_all_events_from(1)
        expect(events[0].stream_version).to eq 1
        expect(events[1].stream_version).to eq 2
        expect(events[2].stream_version).to eq 1
      end

      it 'has the correct type' do
        events = event_store.read_all_events_from(1)
        expect(events[0].type).to eq 'test'
        expect(events[1].type).to eq 'ItemRemoved'
        expect(events[2].type).to eq 'ItemAdded'
      end

      it 'has the correct data' do
        events = event_store.read_all_events_from(1)
        expect(events[0].data).to eq('a' => 'b')
        expect(events[1].data.item_id).to eq 1
        expect(events[2].data.item_id).to eq 1
        expect(events[2].data.name).to eq 'Test'
      end

      it 'fetches in batches with limit arg' do
        events = event_store.read_all_events_from(1, limit: 1)
        expect(events.count).to eq 1
        expect(events[0].type).to eq 'test'
      end

      it 'filters by event type if types is given' do
        events = event_store.read_all_events_from(1, types: ['test'])
        expect(events.count).to eq 1
        expect(events[0].type).to eq 'test'
        events = event_store.read_all_events_from(1, types: ['ItemAdded'])
        expect(events.count).to eq 1
        expect(events[0].type).to eq 'ItemAdded'
      end
    end

    describe '#read_stream_events_from' do
      it 'reads events from a given stream' do
        events = event_store.read_stream_events(stream_id)
        expect(events.count).to eq 2
        aggregate_failures do
          expect(events[0].number).to eq 1
          expect(events[0].id).to eq event.id
          expect(events[0].stream_id).to eq stream_id
          expect(events[0].stream_version).to eq 1
          expect(events[0].type).to eq 'test'
          expect(events[0].data).to eq('a' => 'b')
          expect(events[1].number).to eq 2
          expect(events[1].id).to be_instance_of(String)
          expect(events[1].stream_id).to eq stream_id
          expect(events[1].stream_version).to eq 2
          expect(events[1].type).to eq 'ItemRemoved'
          expect(events[1].data.class).to eq ItemRemoved
          expect(events[1].data.item_id).to eq 1
        end
      end
    end
  end
end
