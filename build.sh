#!/bin/sh
docker run --rm \
  --name switch-builder \
  -e GOOS=windows \
  -e GOARCH=386 \
  -v "$(pwd)/out:/out" \
  -v "$(pwd)/app:/app" \
  switch go build -o /out/switch.exe /app/switch.go
