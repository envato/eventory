module PostgresEventStore
  class EventBuilder
    def build(type:, data:)
      klass = resolve_type(type)
      if klass
        klass.new(data)
      else
        data
      end
    end

    private

    def resolve_type(type)
      Object.const_get(type)
    rescue NameError
      nil
    end
  end
end
