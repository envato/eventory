module Eventory
  class Projection
    include EventHandler

    def initialize(database:, namespace: nil)
      @database = database
      @namespace = namespace
    end

    class << self
      def tables
        @tables ||= {}
      end

      def table(name, &block)
        tables[name] = block
      end
    end

    def up
      self.class.tables.each do |table_name, block|
        database.create_table?(namespaced_name(table_name), &block)
      end
    end

    def down
      self.class.tables.each do |table_name, block|
        database.drop_table?(namespaced_name(table_name), &block)
      end
    end

    private

    attr_reader :database, :namespace

    def table(name)
      database[namespaced_name(name)]
    end

    def namespaced_name(name)
      [namespace, name].compact.join('_').to_sym
    end
  end
end
