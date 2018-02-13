class ItemAdded < Eventory::Event
  attribute :item_id
  attribute :name
end

class ItemRemoved < Eventory::Event
  attribute :item_id
end

class ItemStarred < Eventory::Event
  attribute :item_id
end

module EventHelpers
  def recorded_event(id: SecureRandom.uuid,
                     stream_id: SecureRandom.uuid,
                     stream_version: 1,
                     type: 'test',
                     data: {},
                     recorded_at: Time.now.utc,
                     correlation_id: SecureRandom.uuid)
    @number ||= 0
    Eventory::RecordedEvent.new(
      number: @number += 1,
      id: id,
      stream_id: stream_id,
      stream_version: stream_version,
      type: type,
      data: data,
      recorded_at: recorded_at,
      correlation_id: correlation_id,
      causation_id: nil,
      metadata: nil
    )
  end
end

RSpec.configure do |config|
  config.include(EventHelpers)
end
