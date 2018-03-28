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
      freeze
    end

    attr_reader :id, :type, :data, :correlation_id, :causation_id, :metadata

    def to_event_data
      self
    end

    def ==(other)
      id == other.id &&
        type == other.type &&
        data == other.data &&
        correlation_id == other.correlation_id &&
        causation_id == other.causation_id &&
        metadata == other.metadata
    end
  end
end
