CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE events (
  number BIGSERIAL NOT NULL,
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
  _version bigint;
  data jsonb;
  event_number bigint;
  index int;
BEGIN
  num_events := array_length(event_datas, 1);

  select version into current_version from streams where streams.id = _stream_id;
  if current_version is null then
    if expected_version is null or expected_version = 0 then
      begin
        insert into streams (id, version)
                     values (_stream_id, 0);
      exception when unique_violation then
          select version into current_version from streams where streams.id = _stream_id;
      end;
    else
      raise 'Concurrency conflict. Current version: 0, expected version: %', expected_version;
    end if;
  end if;

  if expected_version is null then
    update streams
      set version = version + num_events
      where id = _stream_id
      returning ("version" - num_events + 1) into _version;
  else
    update streams
      set version = version + num_events
      where id = _stream_id
        and version = expected_version
      returning (streams.version - num_events + 1) into _version;
    if not found then
      raise 'Concurrency conflict. Last known expected version: %', expected_version;
    end if;
  end if;

  -- perform pg_advisory_xact_lock(-1);
  -- !execution of code from here is serialized through use of locking above
  index := 1;
  foreach data IN ARRAY(event_datas)
  loop
    insert into events
      (id, stream_id, type, data, stream_version, correlation_id, causation_id, metadata)
    values
      (
        event_ids[index],
        _stream_id,
        event_types[index],
        data,
        _version,
        correlation_ids[index],
        causation_ids[index],
        metadatas[index]
      );

    _version := _version + 1;
    index := index + 1;
  end loop;
END
$$ language plpgsql;

CREATE TABLE checkpoints (
  id SERIAL PRIMARY KEY NOT NULL,
  name VARCHAR(255) NOT NULL,
  event_types VARCHAR(255)[] DEFAULT NULL,
  position BIGINT NOT NULL,
  created_at timestamp without time zone default (now() at time zone 'utc') NOT NULL
);
CREATE INDEX checkpoints_name ON checkpoints (name);

CREATE TABLE streams (
  id UUID PRIMARY KEY NOT NULL,
  version BIGINT NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE UNIQUE INDEX streams_id_version ON streams (id, version);
