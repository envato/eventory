module Eventory
  ConcurrencyError = Class.new(StandardError)

  class EventStore
    def initialize(database:, event_builder: EventBuilder.new)
      @database = database
      @event_builder = event_builder
    end

    def save(stream_id, events, expected_version: nil)
      events = Array(events)
      event_count = events.count
      database.transaction do
        number = claim_next_event_sequence_numbers(event_count)
        stream_version = stream_version(stream_id)
        raise ConcurrencyError if expected_version && expected_version != stream_version
        stream_version += 1
        events.each do |event|
          insert_event(number, stream_id, stream_version, event.to_event_data)
          stream_version += 1
          number += 1
        end
        # TODO: notify new event
      end
    end

    def read_all_events_from(number, types: nil, limit: 1000)
      query = database[:events]
      query = query.where(type: Array(types)) if types
      query
        .where(Sequel.lit('number >= ?', number))
        .order(:number)
        .limit(limit)
        .map { |r| build_recorded_event(r) }
    end

    def read_stream_events(stream_id)
      database[:events]
        .where(stream_id: stream_id)
        .order(:stream_version)
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
    def stream_version(stream_id)
      database[:events].where(stream_id: stream_id).max(:stream_version) || 0
    end

    def build_recorded_event(row)
      event = @event_builder.build(type: row.fetch(:type), data: row.fetch(:data).to_h)
      RecordedEvent.new(
        number: row.fetch(:number),
        id: row.fetch(:id),
        stream_id: row.fetch(:stream_id),
        stream_version: row.fetch(:stream_version),
        type: row.fetch(:type),
        data: event,
        recorded_at: row.fetch(:recorded_at),
        correlation_id: row.fetch(:correlation_id),
        causation_id: row.fetch(:causation_id),
        metadata: row.fetch(:metadata)&.to_h
      )
    end

    def insert_event(number, stream_id, stream_version, event_data)
      database[:events].insert(
        number: number,
        stream_id: stream_id,
        stream_version: stream_version,
        id: event_data.id,
        type: event_data.type,
        data: sequel_jsonb(event_data.data),
        correlation_id: event_data.correlation_id,
        causation_id: event_data.causation_id,
        metadata: sequel_jsonb(event_data.metadata)
      )
    end

    def sequel_jsonb(data)
      if data
        Sequel.pg_jsonb(data)
      else
        nil
      end
    end
  end
end
