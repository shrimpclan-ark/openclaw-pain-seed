# GitHub Repository Review Report

Reviewed repositories:

- https://github.com/shrimpclanai-a11y/pain-merchant-generator-lite
- https://github.com/shrimpclan-ark/openclaw-pain-seed

Date: 2026-06-18

## Findings

### 1. Critical: public password can mint Tailscale auth keys

`matrix-gateway.js` defaults `GATEWAY_PASS` to `shrimpclan-matrix-2026`, and the public IDX scripts use that same value to call `/api/get-key`. Anyone reading the repo can request fresh Tailscale keys from the deployed gateway if it is live.

Recommended fix:

- Rotate `GATEWAY_PASS`, `TS_API_TOKEN`, and any issued Tailscale keys.
- Remove the hardcoded default gateway password.
- Require `GATEWAY_PASS` to be provided as a secret environment variable.
- Add authentication, authorization, and rate limits to the gateway.

References:

- https://github.com/shrimpclan-ark/openclaw-pain-seed/blob/main/matrix-gateway.js#L13-L14
- https://github.com/shrimpclan-ark/openclaw-pain-seed/blob/main/envs/dev-sapper.nix#L51-L52

### 2. Critical: public template installs remote access by default

The IDX startup script auto-enrolls workspaces into a Tailnet, enables `tailscale --ssh`, writes a fixed public key into `authorized_keys`, starts sshd on port `2222`, and reports workspace coordinates to a beacon. This is too much implicit remote access for a public template.

Recommended fix:

- Make Tailnet enrollment and SSH access opt-in.
- Require user-supplied gateway and key material.
- Remove baked-in public keys from the template.
- Clearly document what metadata is sent, where it is sent, and why.

References:

- https://github.com/shrimpclan-ark/openclaw-pain-seed/blob/main/envs/dev-sapper.nix#L60-L73
- https://github.com/shrimpclan-ark/openclaw-pain-seed/blob/main/envs/dev-sapper.nix#L81-L90

### 3. High: `fresh` mode is missing `jq` but uses it

`dev-fresh.nix` parses the gateway response with `jq -r .key`, but the `packages` list includes `curl` and not `jq`. Fresh deployments will fail before Tailscale enrollment.

Recommended fix:

- Add `pkgs.jq` to fresh mode in both repositories.

References:

- https://github.com/shrimpclan-ark/openclaw-pain-seed/blob/main/envs/dev-fresh.nix#L3-L9
- https://github.com/shrimpclan-ark/openclaw-pain-seed/blob/main/envs/dev-fresh.nix#L59

### 4. High: `pain-merchant-generator-lite` IDX links point to `main`, but the repo default branch is `master`

The README button and generator both produce `/tree/main` URLs. This repo's default branch is `master`, so the one-click template link is likely broken unless a `main` branch exists.

Recommended fix:

- Change generated links to `master`, or rename the repository branch to `main`.
- Keep README links and generator defaults aligned with the actual default branch.

References:

- https://github.com/shrimpclanai-a11y/pain-merchant-generator-lite/blob/master/README.md#L7
- https://github.com/shrimpclanai-a11y/pain-merchant-generator-lite/blob/master/index.html#L497

### 5. Medium: `matrix-gateway.js` cannot run from `package.json` dependencies

The gateway requires `express` and `axios`, but `package.json` only installs `playwright`, and `npm start` runs `matrix-creator.js`.

Recommended fix:

- Add `express` and `axios` to dependencies.
- Add a dedicated gateway script, for example `npm run gateway`.
- Consider splitting gateway and matrix creator into separate packages if they have different deployment targets.

References:

- https://github.com/shrimpclan-ark/openclaw-pain-seed/blob/main/matrix-gateway.js#L7-L8
- https://github.com/shrimpclan-ark/openclaw-pain-seed/blob/main/package.json

### 6. Medium: runtime dependencies are unpinned

Startup pulls `decolua/9router:latest`, installs `@anthropic-ai/claude-code` globally without a version, and clones OpenClaw without a pinned commit. This makes deployments non-reproducible and exposes users to upstream breakage or supply-chain changes.

Recommended fix:

- Pin Docker images by digest.
- Pin npm package versions.
- Pin Git dependencies to tags or commit SHAs.
- Add a documented upgrade process.

Reference:

- https://github.com/shrimpclan-ark/openclaw-pain-seed/blob/main/envs/dev-sapper.nix#L137-L177

## Summary

The repositories are small and understandable, but the security model needs tightening before they should be described as production ready. The highest priority fixes are removing public gateway credentials, making remote access opt-in, and rotating any live secrets or issued Tailscale keys. After that, repair the fresh-mode `jq` dependency and align `main`/`master` template links.
