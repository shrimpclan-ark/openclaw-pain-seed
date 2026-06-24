#!/bin/bash
export DOCKER_HOST="unix:///tmp/run-1000/docker.sock"
docker exec openclaw curl -s -I -H "Authorization: Bearer sk-9router" http://172.18.0.3:20128/api/v1/models
docker exec openclaw curl -s -H "Authorization: Bearer sk-9router" http://172.18.0.3:20128/api/v1/models | head -c 200
