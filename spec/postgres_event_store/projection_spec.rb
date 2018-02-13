class TestProjection < PostgresEventStore::Projection
  change do
    create_table :test_table do
      column :sequence_id, 'SERIAL PRIMARY KEY', unique: true
      column :item_id, 'INT NOT NULL'
    end
  end

  on ItemAdded do |event|
    table(:test_table).insert(item_id: event.data.item_id)
  end
end

RSpec.describe PostgresEventStore::Projector do
  context 'schema migrations' do
    it 'creates given tables on up' do
      TestProjection.migrate(database)
      expect(database.table_exists?(:test_table)).to eq true
    end

    it 'removes tables on down' do
      TestProjection.migrate(database)
      TestProjection.migrate(database, :down)
      expect(database.table_exists?(:test_table)).to eq false
    end
  end

  subject(:test_projector) { TestProjection.new(database: database) }

  it 'handles events' do
    TestProjection.migrate(database)
    test_projector.handle(recorded_event(type: 'ItemAdded', data: ItemAdded.new(item_id: 1)))
    expect(database[:test_table].all.first[:item_id]).to eq 1
  end
end
