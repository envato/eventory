RSpec.describe PostgresEventStore do
  it "has a version number" do
    expect(PostgresEventStore::VERSION).not_to be nil
  end
end
