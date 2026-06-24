#!/bin/bash
export DOCKER_HOST="unix:///tmp/run-1000/docker.sock"
export PATH="/nix/store/lmapifc86ql4xysybykc37b4wg02f9i5-docker-29.1.2/bin:/usr/bin:/bin"

echo "Updating openclaw.json to use oc/nemotron-3-ultra-free..."
docker exec openclaw sh -c "
cd /home/node/.openclaw
cat > patch.py << 'EOF'
import json
with open('openclaw.json', 'r') as f:
    config = json.load(f)

config['models']['providers']['9router']['models'] = [
    {
        'id': 'oc/nemotron-3-ultra-free',
        'name': 'Nemotron 3 Ultra (Free)',
        'contextWindow': 128000,
        'maxTokens': 8192,
        'input': ['text'],
        'cost': {'input': 0, 'output': 0, 'cacheRead': 0, 'cacheWrite': 0},
        'reasoning': True
    },
    {
        'id': 'oc/north-mini-code-free',
        'name': 'North Mini Code (Free)',
        'contextWindow': 32000,
        'maxTokens': 4096,
        'input': ['text'],
        'cost': {'input': 0, 'output': 0, 'cacheRead': 0, 'cacheWrite': 0},
        'reasoning': False
    }
]

config['agents']['defaults']['model']['primary'] = '9router/oc/nemotron-3-ultra-free'
config['agents']['defaults']['models'] = {
    '9router/oc/nemotron-3-ultra-free': {},
    '9router/oc/north-mini-code-free': {}
}

with open('openclaw.json', 'w') as f:
    json.dump(config, f, indent=2)
EOF
python3 patch.py
chown node:node openclaw.json
"

echo "Restarting openclaw..."
docker restart openclaw
sleep 5

echo "Testing model..."
docker exec openclaw sh -c 'curl -s --connect-timeout 5 -m 15 -X POST http://172.18.0.3:20128/api/v1/chat/completions \
  -H "Authorization: Bearer sk-9router" \
  -H "Content-Type: application/json" \
  -d "{\"model\":\"oc/nemotron-3-ultra-free\",\"messages\":[{\"role\":\"user\",\"content\":\"say hi\"}],\"max_tokens\":10,\"stream\":false}" 2>&1 | head -5'
