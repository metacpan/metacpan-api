#!/bin/bash

# Courtesy of @fxdgear
# https://github.com/elastic/elasticsearch-py/issues/778#issuecomment-384389668

set -ux

container="$1"
host="$2"

preamble="docker-compose exec $container"

while true; do
    response=$($preamble curl --write-out '%{http_code}' --silent --fail --output /dev/null "$host")
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
    health=$($preamble curl -fsSL "$host/_cat/health?format=JSON" | jq '.[0].status == "yellow" or .[0].status == "green"')
    if [[ $health == 'true' ]]; then
        break
    fi
    echo "Elastic Search is unavailable ($health) - sleeping" >&2
    sleep 1
done

echo "Elastic Search is up" >&2
exit 0
