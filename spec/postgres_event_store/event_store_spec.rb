RSpec.describe PostgresEventStore::EventStore do
  subject(:event_store) { described_class.new(database: database) }

  it 'works' do
    expect(database['select 1 as a'].first[:a]).to eq 1
  end
end
