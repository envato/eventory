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
    end

    def handle(events)
      Array(events).each do |event|
        self.class.event_handlers[event.class].each do |handler|
          instance_exec(event, &handler)
        end
      end
    end
  end
end
