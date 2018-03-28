module Eventory
  class AggregateRoot
    def self.load(id, events)
      new(id).tap do |aggregate|
        aggregate.load_history(events)
      end
    end

    def self.on(*event_classes, &block)
      event_classes.each do |event_class|
        event_handlers.add(event_class, block)
      end
    end

    def self.event_handlers
      @event_handlers ||= EventHandlers.new
    end

    def initialize(id)
      @id = id.to_str
      @version = 0
      @changes = []
    end

    def clear_changes
      @changes = []
    end

    attr_reader :id, :version, :changes

    def load_history(events)
      events.each do |event|
        handle_event(event)
        increment_version
      end
    end

    private

    def increment_version
      @version += 1
    end

    def apply_event(event)
      handle_event(event)
      increment_version
      @changes << event
    end

    def handle_event(recorded_event)
      self.class.event_handlers.for(recorded_event.event_type_class).each do |handler|
        instance_exec(recorded_event, &handler)
      end
    end
  end
end
