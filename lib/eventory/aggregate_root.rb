module Eventory
  class AggregateRoot
    include EventHandler

    def self.load(id, events)
      new(id).tap do |aggregate|
        aggregate.load_history(events)
      end
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
  end
end
