module Eventory
  class RecordedEvent
    attr_reader :number,
                :stream_id,
                :stream_version,
                :id,
                :type,
                :data,
                :correlation_id,
                :causation_id,
                :metadata

    def initialize(number:, id:, stream_id:, stream_version:, type:, data:, recorded_at:, correlation_id:, causation_id:, metadata:)
      @number = number
      @id = id
      @stream_id = stream_id
      @stream_version = stream_version
      @type = type
      @data = data
      @recorded_at = recorded_at
      @correlation_id = correlation_id
      @causation_id = causation_id
      @metadata = metadata
      freeze
    end

    def event_type_class
      data.class
    end
  end
end
