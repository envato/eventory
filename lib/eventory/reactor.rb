module Eventory
  class Reactor < Projector
    private

    def save_event(stream_id, event)
      event_data = event.to_event_data(**{
        correlation_id: _current_event.correlation_id,
        causation_id: _current_event.id,
        metadata: build_event_metadata
      })
      event_store.save(stream_id, event_data)
    end

    def build_event_metadata
      {}
    end
  end
end
