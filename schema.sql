CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE events (
  number BIGINT NOT NULL,
  id UUID DEFAULT uuid_generate_v4() NOT NULL PRIMARY KEY,
  stream_id UUID NOT NULL,
  stream_version BIGINT NOT NULL,
  type VARCHAR(255) NOT NULL,
  data jsonb NOT NULL,
  recorded_at timestamp without time zone default (now() at time zone 'utc') NOT NULL,
  correlation_id UUID DEFAULT NULL,
  causation_id UUID DEFAULT NULL,
  metadata JSONB NOT NULL DEFAULT '{}'
);

CREATE UNIQUE INDEX events_number_index ON events (number);
CREATE UNIQUE INDEX events_stream_id_index ON events (stream_id, stream_version);
CREATE INDEX events_recorded_at_index ON events (recorded_at);
CREATE INDEX events_correlation_id_index ON events (correlation_id);
CREATE INDEX events_causation_id_index ON events (causation_id);

CREATE FUNCTION write_events (_stream_id uuid,
                              expected_version int,
                              event_ids uuid[],
                              event_types varchar[],
                              event_datas jsonb[],
                              correlation_ids uuid[],
                              causation_ids uuid[],
                              metadatas jsonb[]) returns void as $$
DECLARE
  num_events int;
  current_version bigint;
  version bigint;
  data jsonb;
  event_number bigint;
  index int;
BEGIN
  num_events := array_length(event_datas, 1);
  update event_counter set "number" = "number" + num_events returning "number" into version;
  event_number := version - num_events + 1;

  select max(stream_version) into current_version from events where events.stream_id = _stream_id;
  if current_version is null then
    if expected_version is null or expected_version = 0 then
      version := 1;
    else
      raise 'Concurrency conflict. Current version: 0, expected version: %', expected_version;
    end if;
  else
    version := current_version + 1;
    if expected_version is not null then
      if expected_version != current_version then
        raise 'Concurrency conflict. Last known current version: %, expected version: %', current_version, expected_version;
      end if;
    end if;
  end if;

  index := 1;
  foreach data IN ARRAY(event_datas)
  loop
    insert into events
      ("number", id, stream_id, type, data, stream_version, correlation_id, causation_id, metadata)
    values
      (
        event_number,
        event_ids[index],
        _stream_id,
        event_types[index],
        data,
        version,
        correlation_ids[index],
        causation_ids[index],
        metadatas[index]
      );

    event_number := event_number + 1;
    version := version + 1;
    index := index + 1;
  end loop;
END
$$ language plpgsql;

CREATE TABLE event_counter (
  number BIGINT PRIMARY KEY NOT NULL
);
CREATE UNIQUE INDEX event_counter_number on event_counter (number);
INSERT INTO event_counter (number) VALUES (0);
CREATE RULE no_insert_event_counter AS ON INSERT TO event_counter DO INSTEAD NOTHING;
CREATE RULE no_delete_event_counter AS ON DELETE TO event_counter DO INSTEAD NOTHING;

CREATE TABLE checkpoints (
  id SERIAL PRIMARY KEY NOT NULL,
  name VARCHAR(255) NOT NULL,
  event_types VARCHAR(255)[] DEFAULT NULL,
  position BIGINT NOT NULL,
  created_at timestamp without time zone default (now() at time zone 'utc') NOT NULL
);
CREATE INDEX checkpoints_name ON checkpoints (name);
