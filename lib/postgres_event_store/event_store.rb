module PostgresEventStore
  class EventStore
    def initialize(database:)
      @database = database
    end

    def save(stream_id, events)
      events = Array(events)
      database.transaction do
        high_sequence = database[:event_counter].returning(:number).update(Sequel.lit("number = number + #{events.count}")).first[:number]
        sequence = high_sequence - events.count + 1
        events.each do |event|
          database[:events].insert(
            sequence: sequence,
            stream_id: stream_id,
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
  end
end
