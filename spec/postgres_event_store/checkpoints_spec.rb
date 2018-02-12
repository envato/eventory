RSpec.describe PostgresEventStore::Checkpoints do
  subject(:checkpoints) { described_class.new(database: database) }

  it 'builds a Checkpoint instance' do
    checkpoint = checkpoints.checkout('test')
    expect(checkpoint).to be_an_instance_of(PostgresEventStore::Checkpoint)
    expect(checkpoint.name).to eq 'test'
  end
end
