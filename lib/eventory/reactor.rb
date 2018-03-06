module Eventory
  class Reactor < Projector
    private

    def append_event(stream_id, event)
      event_data = event.to_event_data(**{
        correlation_id: current_event.correlation_id,
        causation_id: current_event.id,
        metadata: build_event_metadata
      })
      event_store.append(stream_id, event_data)
    end

    def build_event_metadata
      {}
    end
  end
end
