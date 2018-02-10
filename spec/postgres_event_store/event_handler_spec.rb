class TestHandler
  include PostgresEventStore::EventHandler

  def initialize
    @added = []
    @removed = []
  end

  on ItemAdded do |event|
    @added << event
  end

  on ItemRemoved do |event|
    @removed << event
  end

  attr_accessor :added, :removed
end

RSpec.describe PostgresEventStore::EventHandler do
  subject(:event_handler) { TestHandler.new }
  let(:item_added) { ItemAdded.new(item_id: 1, name: 'Test!') }
  let(:item_removed) { ItemRemoved.new(item_id: 1) }
  let(:item_starred) { ItemStarred.new(item_id: 1) }

  it 'calls the correct block for each event type' do
    event_handler.handle([item_added, item_removed])
    expect(event_handler.added).to eq [item_added]
    expect(event_handler.removed).to eq [item_removed]
  end

  it 'ignores unknown event types' do
    event_handler.handle(item_starred)
    expect(event_handler.added + event_handler.removed).to eq []
  end
end
