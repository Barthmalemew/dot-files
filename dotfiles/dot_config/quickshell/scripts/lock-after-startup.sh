#!/bin/sh

timeout_seconds=10
elapsed=0

while [ "$elapsed" -lt "$timeout_seconds" ]; do
    if qs ipc call lockScreen lock; then
        exit 0
    fi

    sleep 1
    elapsed=$((elapsed + 1))
done

exit 1
