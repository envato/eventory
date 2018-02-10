module PostgresEventStore
  ConcurrencyError = Class.new(StandardError)

  class EventStore
    def initialize(database:)
      @database = database
    end

    def save(stream_id, events, expected_version: nil)
      events = Array(events)
      event_count = events.count
      database.transaction do
        number = claim_next_event_sequence_numbers(event_count)
        stream_version = update_stream_version(stream_id, event_count)
        raise ConcurrencyError if expected_version && expected_version != stream_version
        events.each do |event|
          event_data = event.to_event_data
          database[:events].insert(
            number: number,
            stream_id: stream_id,
            stream_version: stream_version += 1,
            id: event_data.id,
            type: event_data.type,
            data: Sequel.pg_jsonb(event_data.data)
          )
          number += 1
        end
      end
    end

    def read_all_events_from(number, limit: 1000)
      database[:events]
        .where(Sequel.lit('number >= ?', number))
        .order(:number)
        .limit(limit)
        .map { |r| build_recorded_event(r) }
    end

    private

    attr_reader :database

    # Claim the next `event_count` number numbers
    #
    # This also places a row level rock on the single event counter row,
    # effectively serialising event inserts.
    #
    # @return Integer the starting event number number
    def claim_next_event_sequence_numbers(event_count)
      high_number = database[:event_counter].returning(:number).update(Sequel.lit("number = number + #{event_count}")).first[:number]
      high_number - event_count + 1
    end

    # Update and return the starting stream version number
    #
    # @return Integer the starting stream version number
    def update_stream_version(stream_id, event_count)
      database[:events].where(stream_id: stream_id).max(:stream_version) || 0
    end

    def build_recorded_event(row)
      RecordedEvent.new(
        number: row[:number],
        id: row[:id],
        stream_id: row[:stream_id],
        stream_version: row[:stream_version],
        type: row[:type],
        data: row[:data].to_h,
        recorded_at: row[:recorded_at],
      )
    end
  end
end
