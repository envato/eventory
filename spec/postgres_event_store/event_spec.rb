class ItemAdded < PostgresEventStore::Event
  attribute :item_id
  attribute :name
end

RSpec.describe PostgresEventStore::Event do
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
end
