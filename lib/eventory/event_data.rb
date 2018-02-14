module Eventory
  class EventData
    def initialize(id: SecureRandom.uuid,
                   type:,
                   data:,
                   correlation_id: nil,
                   causation_id: nil,
                   metadata: {})
      @id = id
      @type = type
      @data = data
      @correlation_id = correlation_id
      @causation_id = causation_id
      @metadata = metadata
    end

    attr_reader :id, :type, :data, :correlation_id, :causation_id, :metadata

    def to_event_data
      self
    end
  end
end
