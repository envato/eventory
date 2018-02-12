module PostgresEventStore
  class Checkpoints
    def initialize(database:)
      @database = database
    end

    # TODO: ensure only one processor can checkout a checkpoint.
    # Use a row level lock / for update?
    def checkout(processor)
      Checkpoint.new(
        database: @database,
        name: processor.to_s
      )
    end
  end
end
