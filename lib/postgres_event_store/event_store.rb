module PostgresEventStore
  class EventStore
    def initialize(database:)
      @database = database
    end
  end
end
