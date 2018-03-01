module Eventory
  ConcurrencyError = Class.new(StandardError)

  class EventStore
    def initialize(database:, event_builder: EventBuilder.new)
      @database = database
      @event_builder = event_builder
    end

    def append(stream_id, events, expected_version: nil)
      events = Array(events)
      database.run write_events_sql(stream_id, events.map(&:to_event_data), expected_version)
    rescue Sequel::DatabaseError => e
      if e.message =~ /Concurrency conflict/
        raise ConcurrencyError, "expected version was not #{expected_version}. Error: #{e.message}"
      else
        raise
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

    def write_events_sql(stream_id, events, expected_version)
      datas = sql_literal_array(events, 'jsonb', &:data)
      types = sql_literal_array(events, 'varchar', &:type)
      event_ids = sql_literal_array(events, 'uuid', &:id)
      correlation_ids = sql_literal_array(events, 'uuid', &:correlation_id)
      causation_ids = sql_literal_array(events, 'uuid', &:causation_id)
      metadata = sql_literal_array(events, 'jsonb', &:metadata)
      sql = <<-SQL
        select write_events(
          #{sql_literal(stream_id, 'uuid')},
          #{sql_literal(expected_version, 'int')},
          #{event_ids},
          #{types},
          #{datas},
          #{correlation_ids},
          #{causation_ids},
          #{metadata}
        );
      SQL
      sql
    end

    def sql_literal_array(events, type, &block)
      sql_array = events.map do |event|
        to_sql_literal(block.call(event))
      end.join(', ')
      "array[#{sql_array}]::#{type}[]"
    end

    def sql_literal(value, type)
      "#{to_sql_literal(value)}::#{type}"
    end

    def to_sql_literal(value)
      return 'null' unless value
      wrapped_value = if Hash === value
                        Sequel.pg_jsonb(value)
                      else
                        value
                      end
      database.literal(wrapped_value)
    end
  end
end
