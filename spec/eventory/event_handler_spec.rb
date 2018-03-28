RSpec.describe Eventory::EventHandler do
  subject(:event_handler) { event_handler_class.new }

  let(:event_handler_class) do
    Class.new do
      include Eventory::EventHandler

      def initialize
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
  end
  let(:item_added) { recorded_event(type: 'ItemAdded', data: ItemAdded.new(item_id: 1, name: 'Test!')) }
  let(:item_removed) { recorded_event(type: 'ItemRemoved', data: ItemRemoved.new(item_id: 1)) }
  let(:item_starred) { recorded_event(type: 'ItemStarred', data: ItemStarred.new(item_id: 1)) }

  it 'calls the correct block for each event type' do
    event_handler.handle([item_added, item_removed])
    expect(event_handler.added).to eq [item_added]
    expect(event_handler.removed).to eq [item_removed]
  end

  it 'ignores unknown event types' do
    event_handler.handle(item_starred)
    expect(event_handler.added + event_handler.removed).to eq []
  end

  it 'returns handled event classes' do
    expect(event_handler_class.handled_event_classes).to eq([ItemAdded, ItemRemoved])
  end
end
