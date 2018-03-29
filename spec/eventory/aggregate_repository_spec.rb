class EmailChanged < Eventory::Event
  attribute :new_email
end

class User < Eventory::Domain::AggregateRoot
  on EmailChanged do |event|
    @email = event.new_email
  end

  attr_reader :email

  def change_email(email)
    apply_event EmailChanged.new(new_email: email)
  end
end

RSpec.describe Eventory::Domain::AggregateRepository do
  let(:event_store) { instance_double(Eventory::EventStore::Postgres::EventStore) }
  let(:aggregate_id) { SecureRandom.uuid }
  subject(:aggregate_repository) { described_class.new(event_store, User) }
  let(:aggregate) { aggregate_repository.load(aggregate_id) }

  before do
    allow(event_store).to receive(:read_stream_events)
      .with(aggregate_id)
      .and_return(events)
  end

  context 'when the stream has no events' do
    let(:events) { [] }

    it 'load a new aggregate at version 0' do
      expect(aggregate).to be_an_instance_of(User)
      expect(aggregate.version).to eq 0
    end

    it 'has no changes' do
      expect(aggregate.changes).to be_empty
    end

    it 'saves new events' do
      event_id = SecureRandom.uuid
      allow(SecureRandom).to receive(:uuid).and_return event_id

      aggregate.change_email('test2@test.com')
      expect(event_store).to receive(:append_events)
        .with(aggregate_id,
             [Eventory::EventData.new(type: 'EmailChanged', data: {new_email: 'test2@test.com'})],
             expected_version: 0)
      aggregate_repository.save(aggregate)
    end
  end

  context 'when the stream has events' do
    let(:events) { [recorded_event(data: EmailChanged.new(new_email: 'test@test.com'))] }

    it 'load a new aggregate at version 1' do
      expect(aggregate).to be_an_instance_of(User)
      expect(aggregate.version).to eq 1
    end

    it 'applies the event' do
      expect(aggregate.email).to eq 'test@test.com'
    end

    it 'has no changes' do
      expect(aggregate.changes).to be_empty
    end

    it 'saves new events' do
      event_id = SecureRandom.uuid
      allow(SecureRandom).to receive(:uuid).and_return event_id
      aggregate.change_email('test2@test.com')
      expect(event_store).to receive(:append_events)
        .with(aggregate_id,
             [Eventory::EventData.new(type: 'EmailChanged', data: {new_email: 'test2@test.com'})],
             expected_version: 1)
      aggregate_repository.save(aggregate)
    end
  end
end
