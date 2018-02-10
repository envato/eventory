module PostgresEventStore
  class EventData
    def initialize(id: SecureRandom.uuid,
                   type:,
                   data:)
      @id = id
      @type = type
      @data = data
    end

    attr_reader :id, :type, :data
  end
end

