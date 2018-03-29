RSpec.describe Eventory::EventStreamProcessing::Postgres::Checkpoints do
  subject(:checkpoints) { described_class.new(database: database) }

  it 'builds a Checkpoint instance' do
    checkpoint = checkpoints.checkout(processor_name: 'test', event_types: ['test'])
    expect(checkpoint).to be_an_instance_of(Eventory::EventStreamProcessing::Postgres::Checkpoint)
    expect(checkpoint.name).to eq 'test'
  end
end
