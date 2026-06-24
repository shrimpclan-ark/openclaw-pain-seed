#!/bin/bash
export DOCKER_HOST="unix:///tmp/run-1000/docker.sock"
docker exec openclaw sh -c "sed -i 's|http://172.18.0.3:20128/api|http://172.18.0.3:20128/api/v1|' /home/node/.openclaw/openclaw.json && cat /home/node/.openclaw/openclaw.json | grep baseUrl"
docker restart openclaw
sleep 5
echo "=== TESTING AGAIN ==="
docker logs openclaw --tail 5
