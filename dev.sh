#!/bin/sh
docker run --rm -it \
  --name switch-builder \
  -e GOOS=linux \
  -e GOARCH=386 \
  -v "$(pwd)/app:/app" \
  switch sh
