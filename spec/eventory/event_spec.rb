RSpec.describe Eventory::Event do
  let(:event) { ItemAdded.new(item_id: 1, name: 'test') }

  it 'exposes attributes with accessors' do
    expect(event.item_id).to eq 1
    expect(event.name).to eq 'test'
  end

  it 'returns event data' do
    event_data = event.to_event_data
    expect(event_data.data).to eq(item_id: 1, name: 'test')
    expect(event_data.type).to eq('ItemAdded')
  end

  describe '#==' do
    specify 'equality is based on type + attributes' do
      expect(event).to eq ItemAdded.new(item_id: 1, name: 'test')
      expect(event).to_not eq ItemAdded.new(item_id: 1, name: 'test2')
      expect(ItemRemoved.new(item_id: 1)).to_not eq ItemStarred.new(item_id: 1)
    end
  end
end
