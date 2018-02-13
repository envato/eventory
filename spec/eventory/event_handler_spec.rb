class TestHandler
  include Eventory::EventHandler

  def initialize
    @added = []
    @removed = []
  end

  on ItemAdded do |recorded_event|
    @added << recorded_event
    @current_event_in_processing = _current_event
  end

  on ItemRemoved do |recorded_event|
    @removed << recorded_event
  end

  attr_reader :added, :removed, :current_event_in_processing
end

RSpec.describe Eventory::EventHandler do
  subject(:event_handler) { TestHandler.new }
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

  it 'sets an ivar with the current processing event' do
    event_handler.handle(item_added)
    expect(event_handler.current_event_in_processing).to eq item_added
  end

  it 'returns handled event classes' do
    expect(TestHandler.handled_event_classes).to eq([ItemAdded, ItemRemoved, ItemStarred])
  end
end
