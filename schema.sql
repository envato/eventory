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

CREATE TABLE streams (
  id UUID PRIMARY KEY NOT NULL,
  version BIGINT NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE UNIQUE INDEX streams_id_version ON streams (id, version);

-- Creates a record for a given stream in the streams table if it doesn't already exist
CREATE FUNCTION ensure_stream_exists (stream_id uuid) returns void as $$
DECLARE
  current_version bigint;
BEGIN
  select version into current_version from streams where streams.id = stream_id;
  if current_version is null then
    begin
      insert into streams (id, version)
                   values (stream_id, 0);
    exception when unique_violation then
      -- race condition creating stream. It must exist now, so swallow this error.
    end;
  end if;
END
$$ language plpgsql;

-- Updates stream version by the number of events to be inserted
-- This acquires a row level lock on the stream record, which serializes
-- appends to a stream.
CREATE FUNCTION lock_stream_for_append (_stream_id uuid,
                                        num_events int,
                                        expected_version bigint) returns bigint as $$
DECLARE
  _version bigint;
BEGIN
  if expected_version is null then
    update streams
      set version = version + num_events
      where id = _stream_id
      returning (version - num_events + 1) into _version;
  else
    update streams
      set version = version + num_events
      where id = _stream_id
        and version = expected_version
      returning (version - num_events + 1) into _version;
    if not found then
      raise 'Concurrency conflict. Last known expected version: %', expected_version;
    end if;
  end if;
  return _version;
END
$$ language plpgsql;

-- Append events to a stream
CREATE FUNCTION append_events (_stream_id uuid,
                               expected_version bigint,
                               event_ids uuid[],
                               event_types varchar[],
                               event_datas jsonb[],
                               correlation_ids uuid[],
                               causation_ids uuid[],
                               metadatas jsonb[]) returns void as $$
DECLARE
  num_events int;
  _version bigint;
  data jsonb;
  event_number bigint;
  index int;
BEGIN
  num_events := array_length(event_datas, 1);
  perform ensure_stream_exists(_stream_id);
  select lock_stream_for_append(_stream_id, num_events, expected_version) into _version;

  perform pg_advisory_xact_lock(-1);
  -- execution of code from here is serialized through use of locking above
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
