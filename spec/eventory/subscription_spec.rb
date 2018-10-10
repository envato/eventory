RSpec.describe Eventory::EventStreamProcessing::Subscription do
  subject(:subscription) { described_class.new(event_store: event_store, from_event_number: from_event_number, event_types: ['test']) }
  let(:from_event_number) { 0 }
  let(:event_store) { instance_double(Eventory::PostgresEventStore) }
  let(:events) { [instance_double(Eventory::RecordedEvent, number: 1)] }

  it 'reads new events from the starting position then from the last event number + 1' do
    allow(event_store).to receive(:read_all_events_from)
      .and_return(events, [:stop])
    subscription.start do |events|
      throw :stop if events == [:stop]
    end
    expect(event_store).to have_received(:read_all_events_from)
      .with(0, types: ['test'], limit: 1000).ordered
    expect(event_store).to have_received(:read_all_events_from)
      .with(2, types: ['test'], limit: 1000).ordered
  end

  it 'sleeps when no events are found' do
    allow(Kernel).to receive(:sleep)
    allow(event_store).to receive(:read_all_events_from)
      .and_return([], [:stop])
    subscription.start do |events|
      throw :stop if events == [:stop]
    end
    expect(Kernel).to have_received(:sleep).with(0.5)
  end
end
