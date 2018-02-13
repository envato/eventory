class TestProjector < PostgresEventStore::Projector
  # projector_options processor_name: 'test',
  #                   table_namespace: 'test',
  #                   version: 1
  #
  # projection TestProjection
  # projection do
  #   change { create_table(:test) }
  # end
  #
  # on ItemAdded do |e|
  # end
end
