class TestReactor < Eventory::Reactor
  subscription_options processor_name: 'test_reactor'

  on ItemAdded do |recorded_event|
    added << recorded_event
    append_event(recorded_event.stream_id, ItemRemoved.new(item_id: recorded_event.data.item_id))
  end

  def added
    @added ||= []
  end

  private

  def build_event_metadata
    { git_sha: '123' }
  end
end

RSpec.describe Eventory::Reactor do
  subject(:test_reactor) { TestReactor.new(event_store: event_store, checkpoints: checkpoints) }
  let(:event_store) { Eventory::EventStore.new(database: database) }
  let(:checkpoints) { Eventory::Checkpoints.new(database: database) }
  let(:namespace) { 'ns' }

  it 'handles events' do
    recorded_event = recorded_event(type: 'ItemAdded', data: ItemAdded.new(item_id: 1))
    test_reactor.process(recorded_event)
    expect(test_reactor.added).to eq [recorded_event]
  end

  it 'saves events' do
    recorded_event = recorded_event(type: 'ItemAdded', data: ItemAdded.new(item_id: 1))
    test_reactor.process(recorded_event)
    event = event_store.read_all_events_from(1).last
    expect(event.type).to eq 'ItemRemoved'
    expect(event.data.item_id).to eq 1
  end

  it 'sets causation_id to the ID of the triggering event' do
    recorded_event = recorded_event(type: 'ItemAdded', data: ItemAdded.new(item_id: 1))
    test_reactor.process(recorded_event)
    event = event_store.read_all_events_from(1).last
    expect(event.causation_id).to eq recorded_event.id
  end

  it 'sets causation_id to the ID of the triggering event' do
    correlation_id = SecureRandom.uuid
    recorded_event = recorded_event(type: 'ItemAdded', data: ItemAdded.new(item_id: 1), correlation_id: correlation_id)
    test_reactor.process(recorded_event)
    event = event_store.read_all_events_from(1).last
    expect(event.correlation_id).to eq correlation_id
  end

  it 'allows build_event_metadata to be overridden to set metadata on saved events' do
    recorded_event = recorded_event(type: 'ItemAdded', data: ItemAdded.new(item_id: 1))
    test_reactor.process(recorded_event)
    event = event_store.read_all_events_from(1).last
    expect(event.metadata['git_sha']).to eq '123'
  end

  it 'tracks positions' do
    checkpoint = checkpoints.checkout(processor_name: 'test_reactor')
    test_reactor.process(recorded_event(type: 'ItemAdded', data: ItemAdded.new(item_id: 1)))
    expect(checkpoint.position).to eq 1
    test_reactor.process(recorded_event(type: 'ItemAdded', data: ItemAdded.new(item_id: 2)))
    expect(checkpoint.position).to eq 2
  end
end
