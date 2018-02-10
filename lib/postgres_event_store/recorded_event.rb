module PostgresEventStore
  class RecordedEvent
    attr_reader :number,
                :stream_id,
                :stream_version,
                :id,
                :type,
                :data

    def self.resolve_type(type)
      Object.const_get(type)
    rescue NameError
      nil
    end

    def initialize(number:, id:, stream_id:, stream_version:, type:, data:, recorded_at:)
      @number = number
      @id = id
      @stream_id = stream_id
      @stream_version = stream_version
      @type = type
      event_class = self.class.resolve_type(type)
      @data = if event_class
        event_class.new(data)
      else
        data
      end
      @recorded_at = recorded_at
    end
  end
end
