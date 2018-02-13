module Eventory
  class Projection < EventStreamProcessor
    include EventHandler
    include SchemaOwner

    def initialize(event_store:, checkpoints:, database:, namespace: nil)
      @database = database
      @namespace = namespace
      super(event_store: event_store, checkpoints: checkpoints)
    end

    private

    attr_reader :database, :namespace
  end
end
