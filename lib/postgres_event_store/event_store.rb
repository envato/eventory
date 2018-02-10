module PostgresEventStore
  class EventStore
    def initialize(database:)
      @database = database
    end

    def save(stream_id, events)
      events = Array(events)
      event_count = events.count
      database.transaction do
        sequence = claim_next_event_sequence_numbers(event_count)
        stream_version = update_stream_version(stream_id, event_count)
        events.each do |event|
          database[:events].insert(
            sequence: sequence,
            stream_id: stream_id,
            stream_version: stream_version += 1,
            id: event.id,
            type: event.type,
            data: Sequel.pg_jsonb(event.data)
          )
          sequence += 1
        end
      end
    end

    private

    attr_reader :database

    # Claim the next `event_count` sequence numbers
    #
    # This also places a row level rock on the single event counter row,
    # effectively serialising event inserts.
    #
    # @return Integer the starting event sequence number
    def claim_next_event_sequence_numbers(event_count)
      high_sequence = database[:event_counter].returning(:number).update(Sequel.lit("number = number + #{event_count}")).first[:number]
      high_sequence - event_count + 1
    end

    # Update and return the starting stream version number
    #
    # @return Integer the starting stream version number
    def update_stream_version(stream_id, event_count)
      row = database[:streams].for_update.where(id: stream_id).first
      stream_version = nil
      if row
        stream_version = row[:version]
        database[:streams].where(id: stream_id).update(version: stream_version + event_count)
      else
        stream_version = 0
        database[:streams].insert(id: stream_id, version: event_count)
      end
      stream_version
    end

  end
end
