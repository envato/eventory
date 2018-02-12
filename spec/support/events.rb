class ItemAdded < PostgresEventStore::Event
  attribute :item_id
  attribute :name
end

class ItemRemoved < PostgresEventStore::Event
  attribute :item_id
end

class ItemStarred < PostgresEventStore::Event
  attribute :item_id
end
