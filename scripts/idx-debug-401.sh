#!/bin/bash
export DOCKER_HOST="unix:///tmp/run-1000/docker.sock"
export PATH="/nix/store/lmapifc86ql4xysybykc37b4wg02f9i5-docker-29.1.2/bin:/usr/bin:/bin"

echo "=== openclaw.json ==="
docker exec openclaw sh -c "cat /home/node/.openclaw/openclaw.json"

echo "=== apiKeys in 9router ==="
docker exec 9router sh -c 'node -e "
    const db = require(\"better-sqlite3\")(\"/app/data/db/data.sqlite\");
    const keys = db.prepare(\"SELECT * FROM apiKeys WHERE isActive=1\").all();
    console.log(keys);
"'
