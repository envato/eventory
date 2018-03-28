RSpec.describe Eventory::AggregateRoot do
  let(:aggregate_uuid) { SecureRandom.uuid }
  let(:aggregate_class) do
    Class.new(Eventory::AggregateRoot) do
      def initialize(id)
        @item_added_events = []
        @item_removed_events = []
        @added_and_removed_events = []
        super
      end

      on ItemAdded do |event|
        @item_added_events << event
      end

      on ItemRemoved do |event|
        @item_removed_events << event
      end

      on ItemAdded, ItemRemoved do |event|
        @added_and_removed_events << event
      end

      def add_item(item)
        apply_event ItemAdded.new(item_id: item.id, name: item.name)
      end

      attr_reader :item_added_events,
                  :item_removed_events,
                  :added_and_removed_events
    end
  end
  subject(:aggregate) { aggregate_class.load(aggregate_uuid, events) }

  context 'with no initial events' do
    let(:events) { [] }

    it 'initialises at version 0' do
      expect(aggregate.version).to eq 0
    end
  end

  context 'with initial events' do
    let(:events) { [ItemAdded.new(id: 1), ItemRemoved.new(id: 2)] }

    it 'calls registered handlers' do
      expect(aggregate.item_added_events).to eq [events.first]
      expect(aggregate.item_removed_events).to eq [events.last]
      expect(aggregate.added_and_removed_events).to eq events
    end

    it "updates it's version" do
      expect(aggregate.version).to eq events.count
    end

    context 'with unknown event types' do
      let(:events) { [ItemStarred.new(id: 1)] }

      it 'ignores unknown event types' do
        expect(aggregate.item_added_events + aggregate.item_removed_events + aggregate.added_and_removed_events).to eq []
      end
    end
  end

  context 'when state changes' do
    let(:events) { [] }

    before do
      aggregate.add_item(OpenStruct.new(id: 1234))
    end

    it 'updates state by calling the handler' do
      event = aggregate.item_added_events.first.to_event_data
      expect(event.type).to eq 'ItemAdded'
      expect(event.data[:item_id]).to eq 1234
    end

    it "increments it's version" do
      expect(aggregate.version).to eq 1
    end

    it 'exposes the new event in changes' do
      emitted_event = aggregate.changes.first.to_event_data
      expect(emitted_event.type).to eq 'ItemAdded'
      expect(emitted_event.data[:item_id]).to eq 1234
    end

    context 'when changes are cleared' do
      it 'has no changes' do
        aggregate.clear_changes
        expect(aggregate.changes).to eq []
      end

      it 'has the same version' do
        expect {
          aggregate.clear_changes
        }.to_not change { aggregate.version }
      end
    end

    context 'multiple state changes' do
      before do
        aggregate.add_item(OpenStruct.new(id: 1235))
        aggregate.add_item(OpenStruct.new(id: 1236))
      end

      it 'exposes the events in order' do
        emitted_versions = aggregate.changes.map { |e| e.to_event_data.data[:item_id] }
        expect(emitted_versions).to eq([1234, 1235, 1236])
      end

      it "increments it's version" do
        expect(aggregate.version).to eq 3
      end
    end
  end

end
