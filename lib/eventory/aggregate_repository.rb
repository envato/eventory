module Eventory
  class AggregateRepository
    def initialize(event_store, aggregate_class)
      @event_store = event_store
      @aggregate_class = aggregate_class
    end

    def load(aggregate_id)
      recorded_events = @event_store.read_stream_events(aggregate_id)
      events = recorded_events.map(&:data)
      @aggregate_class.new(aggregate_id, events)
    end

    def save(aggregate)
      new_events = aggregate.changes
      if new_events.any?
        expected_version = aggregate.version - new_events.count
        @event_store.append_events(aggregate.id,
                                   new_events,
                                   expected_version: expected_version)
      end
      aggregate.clear_changes
      true
    end
  end
end
