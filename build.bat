@echo off
docker run --rm --name switch-builder -e GOOS=windows -e GOARCH=386 -v "%cd%/out:/out" -v "%cd%/app:/app" switch go build -o /out/switch.exe /app/switch.go
@echo on
