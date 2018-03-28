require 'uuidtools'
require 'pry'
require 'securerandom'
$LOAD_PATH << '../lib'
require 'eventory'

class ToDoListCreated < Eventory::Event
  attribute :name
end

class ToDoAdded < Eventory::Event
  attribute :id
  attribute :name
end

class ToDoCompleted < Eventory::Event
  attribute :id
end

class ToDo
  def initialize(id:, name:)
    @id = id
    @name = name
    @complete = false
  end

  def complete
    @complete = true
  end

  attr_reader :id, :name
end

class ToDoList < Eventory::AggregateRoot
  def initialize(id)
    super
    @todos = {}
    @todo_id_seq = 0
  end

  on ToDoListCreated do |event|
    @name = event.name
  end

  def create(name:)
    apply_event ToDoListCreated.new(name: name)
  end

  on ToDoAdded do |event|
    @todo_id_seq = event.id
    @todos[event.id] = ToDo.new(id: event.id, name: event.name)
  end

  def add_todo(name:)
    apply_event ToDoAdded.new(id: next_todo_id, name: name)
  end

  on ToDoCompleted do |event|
    @todos[event.id].complete
  end

  def complete(id:)
    apply_event ToDoCompleted.new(id: id)
  end

  private

  def next_todo_id
    @todo_id_seq += 1
  end
end

class ToDoListProjection < Eventory::EventStreamProcessor
  def initialize(event_store:, checkpoints:)
    super
    @lists = {}
  end

  on ToDoListCreated do |event|
    @lists[event.stream_id] = event.data.name
  end

  attr_reader :lists
end

class ToDoProjection < Eventory::EventStreamProcessor
  def initialize(event_store:, checkpoints:)
    super
    @todos_by_list = {}
  end

  on ToDoAdded do |event|
    @todos_by_list[event.stream_id] ||= []
    @todos_by_list[event.stream_id] << ToDo.new(id: event.data.id, name: event.data.name)
  end

  on ToDoCompleted do |event|
    @todos_by_list[event.stream_id] ||= []
    todo = @todos_by_list[event.stream_id].find { |todo| todo.id == event.data.id }
    raise "ToDo not found! #{event.inspect}" unless todo
    todo.complete
  end

  attr_reader :todos_by_list
end

# Hack to save position in memory only
class Checkpoints
  class Checkpoint
    def initialize
      @position = 0
    end

    def save_position(position)
      @position = position
    end

    def position
      @position
    end

    def transaction
      yield
    end
  end

  def checkout(args)
    Checkpoint.new
  end
end

class API
  def initialize(db:)
    @db = db
  end

  def create_todo_list(id:, name:)
    todo_list = ToDoList.new(id)
    todo_list.create(name: name)
    todo_list_repository.save(todo_list)
  end

  def add_todo(todo_list_id:, name:)
    todo_list = todo_list_repository.load(todo_list_id)
    todo_list.add_todo(name: name)
    todo_list_repository.save(todo_list)
  end

  def complete_todo(todo_list_id:, id:)
    todo = todo_list_repository.load(todo_list_id)
    todo.complete(id: id)
    todo_list_repository.save(todo)
  end

  def list_todos
    run_projection(ToDoProjection).todos_by_list
  end

  def list_todo_lists
    run_projection(ToDoListProjection).lists
  end

  def display_projections
    puts "Lists:"
    p list_todo_lists
    puts

    puts "Todos:"
    p list_todos
    nil
  end

  def start_console
    display_projections
    binding.pry
  end

  def reset_db
    @db.execute "truncate table events"
    @db.execute "truncate table streams"
  end

  def uuid(identifier)
    UUIDTools::UUID.sha1_create(UUIDTools::UUID_DNS_NAMESPACE, identifier.to_s).to_s
  end

  def seed_events
    create_todo_list(id: uuid(:inbox), name: 'Inbox')
    create_todo_list(id: uuid(:books), name: 'Books')
    add_todo(todo_list_id: uuid(:inbox), name: 'Wake up')
  end

  private

  def run_projection(klass)
    klass.new(event_store: event_store, checkpoints: ::Checkpoints.new).tap do |projection|
      events = event_store.read_all_events_from(0)
      projection.process(events)
    end
  end

  def repository(aggregate_class)
    Eventory::AggregateRepository.new(event_store, aggregate_class)
  end

  def todo_repository
    repository(ToDo)
  end

  def todo_list_repository
    repository(ToDoList)
  end

  def event_store
    Eventory::EventStore.new(database: @db)
  end
end


db = Sequel.connect(adapter: 'postgres',
                    host: '127.0.0.1',
                    database: 'eventory_test')
Sequel.extension(:pg_array_ops)
db.extension(:pg_array)
db.extension(:pg_json)
db.logger = Logger.new(STDOUT) if ENV['LOG']

event_store = Eventory::EventStore.new(database: db)
api = API.new(db: db)

def uuid(identifier)
  UUIDTools::UUID.sha1_create(UUIDTools::UUID_DNS_NAMESPACE, identifier.to_s).to_s
end

api.reset_db
api.seed_events
api.start_console
