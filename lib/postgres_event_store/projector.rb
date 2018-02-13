Sequel.extension :migration

module PostgresEventStore
  class Projector < EventStreamProcessor
    def initialize(event_store:, checkpoints:, database:)
      @database = database
      super
    end
  end
end
