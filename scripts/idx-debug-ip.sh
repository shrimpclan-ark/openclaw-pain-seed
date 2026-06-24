#!/bin/bash
export DOCKER_HOST="unix:///tmp/run-1000/docker.sock"
export PATH="/nix/store/lmapifc86ql4xysybykc37b4wg02f9i5-docker-29.1.2/bin:/usr/bin:/bin"

echo "=== 9Router Networks ==="
docker inspect 9router --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}}: {{$v.IPAddress}}{{end}}'

echo "=== OpenClaw networks ==="
docker inspect openclaw --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}}: {{$v.IPAddress}}{{end}}'

echo "=== Curl from OpenClaw (http://172.18.0.3:20128/api/v1/models) ==="
docker exec openclaw curl -s -I http://172.18.0.3:20128/api/v1/models || echo "CURL FAILED"

echo "=== Curl from OpenClaw (http://172.18.0.3:20128/api/models) ==="
docker exec openclaw curl -s -I http://172.18.0.3:20128/api/models || echo "CURL FAILED"

echo "=== Curl from OpenClaw to 172.17.0.2 ==="
docker exec openclaw curl -s -I http://172.17.0.2:20128/api/v1/models || echo "CURL FAILED"
