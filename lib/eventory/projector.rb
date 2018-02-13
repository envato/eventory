module Eventory
  class Projector < EventStreamProcessor
    include EventHandler
    include SchemaOwner

    def initialize(event_store:, checkpoints:, database:, version: nil)
      @database = database
      @version = version
      super(event_store: event_store, checkpoints: checkpoints)
    end

    private

    attr_reader :database, :version

    def namespace
      [processor_name, version].compact.join('_')
    end
  end
end
