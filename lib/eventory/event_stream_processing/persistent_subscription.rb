module Eventory
  module EventStreamProcessing
    class PersistentSubscription
      def initialize(event_store:, checkpoint:, event_types: nil, batch_size: 1000, sleep: 0.5)
        @checkpoint = checkpoint
        @subscription = Subscription.new(
          event_store: event_store,
          from_event_number: checkpoint.position + 1,
          event_types: event_types,
          batch_size: batch_size,
          sleep: sleep
        )
      end

      def start
        @subscription.start do |events|
          @checkpoint.transaction do
            yield events
            @checkpoint.save_position(events.last.number)
          end
        end
      end
    end
  end
end
