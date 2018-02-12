module PostgresEventStore
  class Checkpoint
    def initialize(database:, name:, event_types: nil)
      @database = database
      @name = name
      @event_types = event_types
    end

    def position
      row = checkpoints
        .select(:position)
        .first(name: @name)
      if row
        row[:position]
      else
        0
      end
    end

    def save_position(position)
      rows_affected = checkpoints
        .where(name: @name)
        .update(position: position)
      if rows_affected == 0
        checkpoints.insert(name: @name, position: position, event_types: Sequel.pg_array(@event_types))
      end
    end

    def transaction(&block)
      @database.transaction(&block)
    end

    attr_reader :name

    private

    def checkpoints
      @database[:checkpoints]
    end
  end
end
