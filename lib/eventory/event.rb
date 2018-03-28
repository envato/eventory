module Eventory
  class Event
    def self.attribute(name)
      attributes << name.to_sym
      attr_reader name
    end

    def self.attributes
      @attributes ||= []
    end

    def initialize(event_data)
      event_data_with_symbol_keys = Hash[event_data.map { |k, v| [k.to_sym, v] }]
      self.class.attributes.each do |attribute|
        instance_variable_set("@#{attribute}", event_data_with_symbol_keys[attribute])
      end
      freeze
    end

    def to_event_data(correlation_id: nil, causation_id: nil, metadata: {})
      EventData.new(type: self.class.name,
                    data: attributes,
                    correlation_id: correlation_id,
                    causation_id: causation_id,
                    metadata: metadata)
    end

    def event_type_class
      self.class
    end

    def attributes
      self.class.attributes.each_with_object({}) do |key, hash|
        hash[key] = instance_variable_get("@#{key}")
      end
    end

    def ==(other)
      instance_of?(other.class) && attributes == other.attributes
    end
    alias eql? ==
  end
end
