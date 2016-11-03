@echo off
docker run --rm -it --name switch-builder -e GOOS=linux -e GOARCH=386 -v "%cd%/app:/app" switch sh
@echo on
