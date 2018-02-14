class TestESP < Eventory::EventStreamProcessor
  subscription_options processor_name: 'test-esp',
                       batch_size: 10_000,
                       sleep: 1

  def initialize(event_store:, checkpoints:)
    super
    @added = []
    @removed = []
  end

  on ItemAdded do |recorded_event|
    @added << recorded_event
  end

  on ItemRemoved do |recorded_event|
    @removed << recorded_event
  end

  attr_reader :added, :removed
end

class TestESP2 < Eventory::EventStreamProcessor
end

RSpec.describe Eventory::EventStreamProcessor do
  subject(:esp) { TestESP.new(event_store: event_store, checkpoints: checkpoints) }
  let(:event_store) { Eventory::EventStore.new(database: database) }
  let(:checkpoints) { Eventory::Checkpoints.new(database: database) }
  let(:item_added) { recorded_event(type: 'ItemAdded', data: ItemAdded.new(item_id: 1, name: 'test')) }
  let(:item_removed) { recorded_event(type: 'ItemRemoved', data: ItemRemoved.new(item_id: 1)) }
  let(:esp2) { esp = TestESP2.new(event_store: event_store, checkpoints: checkpoints) }

  def stub_checkpoint
    checkpoint_double = instance_double(Eventory::Checkpoint)
    allow(checkpoint_double).to receive(:transaction).and_yield
    allow(checkpoint_double).to receive(:save_position)
    allow(checkpoints).to receive(:checkout)
      .with(processor_name: 'test-esp',
            event_types: ['ItemAdded', 'ItemRemoved']).and_return(checkpoint_double)
    checkpoint_double
  end

  describe '#process' do
    it 'processes events' do
      esp.process([item_added, item_removed])
      expect(esp.added).to eq [item_added]
      expect(esp.removed).to eq [item_removed]
    end

    it 'saves the last processed event number with checkpoint' do
      esp.process(item_added)
      expect(checkpoints.checkout(processor_name: 'test-esp').position).to eq 1
    end

    it 'wraps event processing in a transaction with checkpoint' do
      checkpoint_double = stub_checkpoint
      esp.process(item_added)
      expect(checkpoint_double).to have_received(:transaction)
    end

    it 'records options as subscription args' do
      expect(TestESP.subscription_args).to eq(processor_name: 'test-esp', batch_size: 10_000, sleep: 1, checkpoint_after: :batch, checkpoint_transaction: true)
    end

    context 'with checkpoint_after :event' do
      before { TestESP.subscription_options(checkpoint_after: :event) }

      it 'saves position after each event processed' do
        checkpoint_double = stub_checkpoint
        expect(checkpoint_double).to receive(:save_position).with(1).ordered
        expect(checkpoint_double).to receive(:save_position).with(2).ordered
        esp.process([item_added, item_removed])
      end

      after { TestESP.subscription_options(checkpoint_after: :batch) }
    end

    context 'with checkpoint_transaction false' do
      before { TestESP.subscription_options(checkpoint_transaction: false) }

      it "doesn't wrap the event batch in a transaction" do
        checkpoint_double = stub_checkpoint
        esp.process(item_added)
        expect(checkpoint_double).to_not have_received(:transaction)
      end

      after { TestESP.subscription_options(checkpoint_transaction: true) }
    end
  end

  describe '#processor_name' do
    it 'returns the correct processor_name' do
      expect(esp.processor_name).to eq 'test-esp'
    end

    context 'without a configured name' do
      it 'defaults to the class name' do
        expect(esp2.processor_name).to eq 'TestESP2'
      end
    end
  end

  describe '#batch_size' do
    it 'can be configured' do
      expect(esp.batch_size).to eq 10_000
    end

    it 'defaults to 1000' do
      expect(esp2.batch_size).to eq 1000
    end
  end

  # TODO: rename to something more meaningful
  describe '#sleep' do
    it 'can be configured' do
      expect(esp.sleep).to eq 1
    end

    it 'defaults to 0.5' do
      expect(esp2.sleep).to eq 0.5
    end
  end

  describe '#start' do
    it 'starts a subscription with correct args' do
      subscription = instance_double(Eventory::Subscription)
      allow(Eventory::Subscription).to receive(:new).and_return(subscription)
      allow(subscription).to receive(:start).and_yield([])
      esp.start
      expect(Eventory::Subscription).to have_received(:new).with(
        event_store: event_store,
        from_event_number: 1,
        event_types: ['ItemAdded', 'ItemRemoved'],
        batch_size: 10_000,
        sleep: 1
      )
    end
  end

  it 'raises given an invalid checkpoint_after value' do
    expect {
      TestESP.subscription_options(checkpoint_after: :something)
    }.to raise_error(ArgumentError)
  end
end
