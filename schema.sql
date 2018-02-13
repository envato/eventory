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
  metadata JSONB DEFAULT NULL
);

CREATE UNIQUE INDEX events_number_index ON events USING btree (number);
CREATE INDEX events_stream_id_index ON events USING btree (stream_id);
CREATE INDEX events_recorded_at_index ON events USING btree (recorded_at);

CREATE TABLE event_counter (
  number INT
);
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
