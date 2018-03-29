module Eventory
  module EventStreamProcessing
    class EventStreamProcessor
      def initialize(event_store:, checkpoints:)
        @event_store = event_store
        @checkpoint = checkpoints.checkout(processor_name: processor_name, event_types: self.class.handled_event_classes.map(&:to_s))
      end

      DEFAULT_SUBSCRIPTION_ARGS = {
        processor_name: -> { name },
        batch_size: 1000,
        sleep: 0.5,
        checkpoint_after: :batch,
        checkpoint_transaction: true
      }

      def self.subscription_args
        @subscription_args ||= DEFAULT_SUBSCRIPTION_ARGS.each_with_object({}) do |(key, value), hash|
          hash[key] = value.respond_to?(:call) ? instance_exec(&value) : value
        end
      end

      def self.subscription_options(processor_name: nil,
                                    batch_size: nil,
                                    sleep: nil,
                                    checkpoint_after: nil,
                                    checkpoint_transaction: nil)
        raise ArgumentError, 'unsupported checkpoint_after value - specify :batch or :event' unless checkpoint_after.nil? || %i[ batch event ].include?(checkpoint_after)
        subscription_args.merge!({ processor_name: processor_name,
                                   batch_size: batch_size,
                                   sleep: sleep,
                                   checkpoint_after: checkpoint_after,
                                   checkpoint_transaction: checkpoint_transaction }.compact)
      end

      DEFAULT_SUBSCRIPTION_ARGS.keys.each do |subscription_option|
        define_method subscription_option do
          self.class.subscription_args.fetch(subscription_option)
        end
      end

      def self.on(*event_classes, &block)
        event_classes.each do |event_class|
          event_handlers.add(event_class, block)
        end
      end

      def self.event_handlers
        @event_handlers ||= EventHandlers.new
      end

      def self.handled_event_classes
        event_handlers.handled_event_classes
      end

      def process(events)
        events = Array(events)
        optional_checkpoint_transaction do
          events.each do |event|
            handle_event(event)
            checkpoint.save_position(event.number) if checkpoint_after == :event
          end
          if checkpoint_after == :batch && !events.empty?
            checkpoint.save_position(events.last.number)
          end
        end
      end

      def start
        subscription = Subscription.new(
          event_store: event_store,
          from_event_number: checkpoint.position + 1,
          event_types: self.class.handled_event_classes.map(&:to_s),
          batch_size: batch_size,
          sleep: sleep
        )
        subscription.start do |events|
          process(events)
        end
      end

      private

      attr_reader :checkpoint, :event_store

      def optional_checkpoint_transaction(&block)
        if checkpoint_transaction
          checkpoint.transaction(&block)
        else
          block.call
        end
      end

      def handle_event(recorded_event)
        self.class.event_handlers.for(recorded_event.event_type_class).each do |handler|
          instance_exec(recorded_event, &handler)
        end
      end
    end
  end
end
