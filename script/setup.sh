#!/bin/bash -e

createdb eventory_test
psql eventory_test < schema.sql

bundle install
