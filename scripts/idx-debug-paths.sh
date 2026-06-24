#!/bin/bash
export DOCKER_HOST="unix:///tmp/run-1000/docker.sock"

echo "=== curl /api/chat/completions ==="
docker exec openclaw curl -s -I -H "Authorization: Bearer sk-9router" http://172.18.0.3:20128/api/chat/completions || echo "FAILED"

echo "=== curl /api/v1/chat/completions ==="
docker exec openclaw curl -s -I -H "Authorization: Bearer sk-9router" http://172.18.0.3:20128/api/v1/chat/completions || echo "FAILED"
