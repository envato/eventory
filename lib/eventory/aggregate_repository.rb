module Eventory
  class AggregateRepository
    def initialize(event_store, aggregate_class, correlation_id: nil, causation_id: nil, metadata: {})
      @event_store = event_store
      @aggregate_class = aggregate_class
      @correlation_id = correlation_id
      @causation_id = causation_id
      @metadata = metadata
    end

    def load(aggregate_id)
      recorded_events = @event_store.read_stream_events(aggregate_id)
      events = recorded_events.map(&:data)
      @aggregate_class.load(aggregate_id, events)
    end

    def save(aggregate)
      new_events = aggregate.changes
      if new_events.any?
        new_events = new_events.map do |event|
          event.to_event_data(
            correlation_id: correlation_id,
            causation_id: causation_id,
            metadata: metadata,
          )
        end

        expected_version = aggregate.version - new_events.count
        @event_store.append_events(aggregate.id,
                                   new_events,
                                   expected_version: expected_version)
      end
      aggregate.clear_changes
      true
    end

    private

    attr_reader :correlation_id, :causation_id, :metadata
  end
end
