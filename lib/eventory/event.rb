module Eventory
  class Event
    def self.attribute(name)
      attributes[name.to_sym] = 1
      attr_reader name
    end

    class << self
      def attributes
        @attributes ||= {}
      end
    end

    def initialize(event_data)
      @event_data = Hash[event_data.map { |k, v| [k.to_sym, v] }]
      self.class.attributes.each_key do |attribute|
        instance_variable_set("@#{attribute}", @event_data[attribute])
      end
    end

    def to_event_data
      EventData.new(type: self.class.name, data: attributes)
    end

    def attributes
      self.class.attributes.keys.each_with_object({}) do |key, hash|
        hash[key] = instance_variable_get("@#{key}")
      end
    end
  end
end
