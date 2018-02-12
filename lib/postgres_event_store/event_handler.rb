module PostgresEventStore
  module EventHandler
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def event_handlers
        @event_handlers ||= Hash.new { |hash, key| hash[key] = [] }
      end

      def on(*event_classes, &block)
        event_classes.each do |event_class|
          event_handlers[event_class] << block
        end
      end

      def handled_event_classes
        event_handlers.keys
      end
    end

    def handle(recorded_events)
      Array(recorded_events).each do |recorded_event|
        self.class.event_handlers[recorded_event.event_type_class].each do |handler|
          instance_exec(recorded_event, &handler)
        end
      end
    end
  end
end
