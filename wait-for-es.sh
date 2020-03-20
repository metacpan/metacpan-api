#!/bin/bash

# Courtesy of @fxdgear
# https://github.com/elastic/elasticsearch-py/issues/778#issuecomment-384389668

set -e

host="$1"
shift
cmd="$@"


until $(curl --output /dev/null --silent --head --fail "$host"); do
    printf '.'
    sleep 1
done

# First wait for ES to start...
response=$(curl $host)

until [ "$response" = "200" ]; do
    response=$(curl --write-out %{http_code} --silent --output /dev/null "$host")
    >&2 echo "Elastic Search is unavailable - sleeping"
    sleep 1
done


# Wait for ES status to turn to yellow.
# TODO: Ideally we'd be waiting for green, but we need multiple nodes for that.

health="$(curl -fsSL "$host/_cat/health?h=status")"
health="$(echo "$health" | sed -r 's/^[[:space:]]+|[[:space:]]+$//g')" # trim whitespace (otherwise we'll have "green ")

until [ "$health" = 'yellow' ]; do
    health="$(curl -fsSL "$host/_cat/health?h=status")"
    health="$(echo "$health" | sed -r 's/^[[:space:]]+|[[:space:]]+$//g')" # trim whitespace (otherwise we'll have "green ")
    >&2 echo "Elastic Search is unavailable ($health) - sleeping"
    sleep 1
done

>&2 echo "Elastic Search is up"
exec $cmd
