module Eventory
  class RecordedEvent
    attr_reader :number,
                :stream_id,
                :stream_version,
                :id,
                :type,
                :data

    def initialize(number:, id:, stream_id:, stream_version:, type:, data:, recorded_at:)
      @number = number
      @id = id
      @stream_id = stream_id
      @stream_version = stream_version
      @type = type
      @data = data
      @recorded_at = recorded_at
    end

    def event_type_class
      data.class
    end
  end
end
