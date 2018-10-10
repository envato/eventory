RSpec.describe Eventory::EventStreamProcessing::Projector do
  def new_projector(&block)
    Class.new(Eventory::EventStreamProcessing::Projector) do
      class_eval(&block) if block_given?
    end
  end

  let(:test_projector_class) do
    new_projector do
      subscription_options processor_name: 'procname'

      attr_accessor :state

      on ItemAdded do |event|
        self.state ||= []
        self.state << event.data.item_id
      end
    end
  end


  subject(:test_projector) { test_projector_class.new(event_store: event_store, checkpoints: checkpoints) }
  let(:event_store) { Eventory::PostgresEventStore.new(database: database) }
  let(:checkpoints) { Eventory::EventStreamProcessing::Postgres::Checkpoints.new(database: database) }
  let(:namespace) { 'ns' }

  it 'handles events' do
    test_projector.process(recorded_event(type: 'ItemAdded', data: ItemAdded.new(item_id: 1)))

    expect(test_projector.state).to eq [1]
  end

  it 'tracks positions' do
    checkpoint = checkpoints.checkout(processor_name: 'procname')
    test_projector.process(recorded_event(type: 'ItemAdded', data: ItemAdded.new(item_id: 1)))
    expect(checkpoint.position).to eq 1
    test_projector.process(recorded_event(type: 'ItemAdded', data: ItemAdded.new(item_id: 2)))
    expect(checkpoint.position).to eq 2
  end
end
