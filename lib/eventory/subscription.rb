module Eventory
  class Subscription
    def initialize(event_store:,
                   from_event_number:,
                   event_types: nil,
                   batch_size: 1000,
                   sleep: 0.5)
      @event_store = event_store
      @from_event_number = from_event_number
      @event_types = event_types
      @batch_size = batch_size
      # TODO: use notify when saving events and listen here to react to
      # that, rather than poll
      @sleep = sleep
    end

    def start
      event_number = @from_event_number
      catch(:stop) do
        loop do
          events = @event_store.read_all_events_from(event_number, types: @event_types, limit: @batch_size)
          if events.empty?
            Kernel.sleep @sleep
          else
            yield events
            event_number = events.last.number + 1
          end
        end
      end
    end
  end
end
