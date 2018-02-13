RSpec.describe Eventory::PersistentSubscription do
  subject(:persistent_subscription) { described_class.new(event_store: event_store, checkpoint: checkpoint, event_types: ['test']) }
  let(:event_store) { double }
  let(:subscription) { instance_double(Eventory::Subscription) }
  let(:events) { [instance_double(Eventory::RecordedEvent, number: 1)] }
  let(:checkpoint) { Eventory::Checkpoint.new(database: database, name: 'test') }

  before do
    allow(Eventory::Subscription).to receive(:new).and_return(subscription)
    allow(subscription).to receive(:start).and_yield(events)
  end

  it 'uses a Subscription with correct args' do
    expect(Eventory::Subscription).to receive(:new).with(
      event_store: event_store,
      from_event_number: 1,
      event_types: ['test'],
      batch_size: 1000,
      sleep: 0.5
    )
    persistent_subscription.start { |_| }
  end

  it 'yields with events from subscription' do
    called_with = nil
    persistent_subscription.start do |events|
      called_with = events
    end
    expect(called_with).to eq events
  end

  it 'saves position with checkpoint' do
    persistent_subscription.start { |_| }
    expect(checkpoint.position).to eq 1
  end
end
