module Eventory
  module SchemaOwner
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
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

    def table(name)
      database[namespaced_name(name)]
    end

    def namespaced_name(name)
      [namespace, name].compact.join('_').to_sym
    end

    def namespace
      # implement in subclass
    end
  end
end
