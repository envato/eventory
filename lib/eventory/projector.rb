module Eventory
  class Projector < EventStreamProcessor
    include EventHandler

    def initialize(event_store:, checkpoints:, version: nil)
      @version = version
      super(event_store: event_store, checkpoints: checkpoints)
    end

    private

    attr_reader :version
  end
end
