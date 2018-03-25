module Eventory
  class Checkpoints
    def initialize(database:)
      @database = database
    end

    # TODO: ensure only one processor can checkout a checkpoint.
    # Use a row level lock / for update?
    def checkout(processor_name:, event_types: nil)
      Checkpoint.new(
        database: @database,
        name: processor_name,
        event_types: event_types
      )
    end
  end
end
