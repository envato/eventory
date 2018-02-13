module PostgresEventStore
  class MigrationDSL < Sequel::MigrationDSL
    def initialize(&block)
      @migration = Sequel::SimpleMigration.new
      instance_exec(&block)
    end
  end

  class Projection
    def initialize(database:, table_namespace: nil)
      @database = database
    end

    include EventHandler

    def self.migration_dsl
      @migration_dsl ||= MigrationDSL.new {
        transaction
      }
    end

    def self.migrate(db, direction = :up)
      migration_dsl.migration.apply(db, direction)
    end

    def self.change(&block)
      migration_dsl.change(&block)
    end

    def self.up(&block)
      migration_dsl.up(&block)
    end

    def self.down(&block)
      migration_dsl.down(&block)
    end

    private

    attr_reader :database

    def table(name)
      database[name]
    end
  end
end
