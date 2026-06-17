// matrix-gateway.js
// 部署方式:
// npm init -y && npm install express axios
// node matrix-gateway.js
// 建議搭配 pm2 或 Docker 部署至 e2-micro 或 Cloud Run

const express = require('express');
const axios = require('axios');
const app = express();

const PORT = process.env.PORT || 8080;
// 這裡的 Token 只有在 Gateway 這台機器上需要 90 天換一次
const TS_API_TOKEN = process.env.TS_API_TOKEN || "";
const GATEWAY_PASS = process.env.GATEWAY_PASS || "shrimpclan-matrix-2026";

app.use(express.json());

app.get('/api/health', (req, res) => {
    res.send({ status: "alive" });
});

app.post('/api/get-key', async (req, res) => {
    const providedPass = req.headers['x-matrix-pass'];
    const agentName = req.body.agent || "unknown";

    if (providedPass !== GATEWAY_PASS) {
        console.warn(`[WARN] Unauthorized access attempt from ${agentName} (${req.ip})`);
        return res.status(401).send({ error: "Unauthorized" });
    }

    try {
        console.log(`[INFO] Generating new Auth Key for agent: ${agentName}`);
        const response = await axios.post(
            'https://api.tailscale.com/api/v2/tailnet/-/keys',
            {
                capabilities: {
                    devices: {
                        create: {
                            reusable: false,
                            ephemeral: false,
                            tags: ["tag:matrix-worker"]
                        }
                    }
                },
                expirySeconds: 300 // 鑰匙 5 分鐘後失效，很安全
            },
            {
                headers: {
                    'Authorization': `Bearer ${TS_API_TOKEN}`
                }
            }
        );

        res.send({ key: response.data.key });
        console.log(`[SUCCESS] Key delivered to ${agentName}`);

    } catch (error) {
        console.error(`[ERROR] Tailscale API failed:`, error.response ? error.response.data : error.message);
        res.status(500).send({ error: "Failed to generate key" });
    }
});

app.listen(PORT, '0.0.0.0', () => {
    console.log(`🦐 Matrix Gateway is running on port ${PORT}`);
    console.log(`   Expected X-Matrix-Pass: ${GATEWAY_PASS}`);
});
