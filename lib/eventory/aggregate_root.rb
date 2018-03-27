module Eventory
  module AggregateRoot
    def self.included(base)
      base.send(:include, EventHandler)
    end

    def initialize(id, events = [])
      @id = id.to_str
      @version = 0
      @changes = []
      load_history(events)
    end

    def clear_changes
      @changes = []
    end

    attr_reader :id, :version, :changes

    private

    def load_history(events)
      events.each do |event|
        handle_event(event)
        increment_version
      end
    end

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
