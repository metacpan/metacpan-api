#!/bin/bash

# Courtesy of @fxdgear
# https://github.com/elastic/elasticsearch-py/issues/778#issuecomment-384389668

set -ux


HOST="$1"
CONTAINER=${2:-""}
PREAMBLE=""

echo "container |$CONTAINER|"
if [[ $CONTAINER != "" ]]; then
    PREAMBLE="docker-compose exec $CONTAINER"
fi

while true; do
    response=$($PREAMBLE curl --write-out '%{http_code}' --silent --fail --output /dev/null "$HOST")
    if [[ "$response" -eq "200" ]]; then
        break
    fi

    echo "Elastic Search is unavailable - sleeping" >&2
    sleep 1
done

# set -e now because it was causing the curl command above to exit the script
# if the server was not available
set -e

COUNTER=0
MAX_LOOPS=60
while true; do
    ## Wait for ES status to turn to yellow.
    ## TODO: Ideally we'd be waiting for green, but we need multiple nodes for that.
    health=$($PREAMBLE curl -fsSL "$HOST/_cat/health?format=JSON" | jq '.[0].status == "yellow" or .[0].status == "green"')
    if [[ $health == 'true' ]]; then
        echo "Elasticsearch is up" >&2
        break
    fi
    echo "Elastic Search is unavailable ($health) - sleeping" >&2
    COUNTER=$((COUNTER + 1))
    if [[ $COUNTER -gt $MAX_LOOPS ]]; then
        echo "Giving up after $COUNTER attempts"
        exit 1
        break
    fi
    sleep 1
done

# Allow commands to be chained
shift
shift
exec "$@"
