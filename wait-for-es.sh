#!/bin/bash

# Courtesy of @fxdgear
# https://github.com/elastic/elasticsearch-py/issues/778#issuecomment-384389668

set -ux

host="$1"

while true; do
    response=$(curl --write-out '%{http_code}' --silent --fail --output /dev/null "$host")
    if [[ "$response" -eq "200" ]]; then
        break
    fi

    echo "Elastic Search is unavailable - sleeping" >&2
    sleep 1
done

# set -e now because it was causing the curl command above to exit the script
# if the server was not available
set -e

while true; do
    ## Wait for ES status to turn to yellow.
    ## TODO: Ideally we'd be waiting for green, but we need multiple nodes for that.
    health="$(curl -fsSL "$host/_cat/health?h=status")"
    health="$(echo "$health" | xargs)" # trim whitespace (otherwise we'll have "green ")
    if [[ $health == 'yellow' || $health == 'green' ]]; then
        break
    fi
    echo "Elastic Search is unavailable ($health) - sleeping" >&2
    sleep 1
done

echo "Elastic Search is up" >&2
shift
exec "$@"
