# Riskonnect Policy Advisor — Mock MCP Server

A small **Cloudflare Worker** that speaks the **Model Context Protocol (MCP)** over JSON-RPC 2.0 and
serves mock policy/regulation intelligence for the [Riskonnect Policy Agent workshop](../GUIDE.md).

> **Facilitators deploy this once and share the host with participants.** Participants do **not** run
> it — they point their Named Credential at the live host (see the main [README](../README.md) and
> [GUIDE.md](../GUIDE.md) Module 2).

## Endpoints

| Method & path | Purpose | Auth |
|---|---|---|
| `POST /oauth/token` | OAuth 2.0 **client-credentials** → Bearer token (`expires_in` 3600s) | client_id + secret (form body or HTTP Basic) |
| `POST /policy-advisor` | JSON-RPC 2.0 MCP endpoint (`initialize`, `tools/list`, `tools/call`, `ping`) | `Authorization: Bearer <token>` |
| `GET /health` | Liveness probe | none |

Tokens are stateless: `base64url(claims).HMAC-SHA256(claims, CLIENT_SECRET)`. No KV/DB required.
`notifications/initialized` returns `202` with no body, per MCP.

## The three tools

| Tool | Input | Returns |
|---|---|---|
| `get_policy_details` | `policy_id` | name, category, owner, last review date, status, content summary |
| `analyze_regulatory_gap` | `policy_id`, `regulation_name` | `overall_compliance`, `compliance_score`, `gaps[]` (article, severity, description, requirement) |
| `recommend_policy_updates` | `policy_id`, `regulation_name` | `recommendations[]` (article, priority, policy_language, rationale, implementation_notes) |

Tool results follow MCP content format — the JSON payload is stringified in `result.content[0].text`.
`policy_id` is case-insensitive; `regulation_name` accepts aliases (e.g. `SEC Cyber Rules` →
`SEC Cybersecurity Rules`, `nist csf` → `NIST Cybersecurity Framework`).

## Mock dataset

5 policies (`POL-001`…`POL-005`) and 5 regulations (GDPR, CCPA, SEC Cybersecurity Rules,
NIST CSF, SOX). The seeded gap/recommendation combos — **POL-001×GDPR, POL-002×SEC,
POL-004×NIST** — mirror `data/seed-gaps.apex` so the agent's MCP answers match the
`Policy_Gap__c` records in the org. Unknown policy/regulation → `isError` tool result; a valid
policy/regulation with no seeded gaps → a "Compliant" response with an empty `gaps` array.

Edit `src/data.js` to change the dataset. **Keep it in sync with `../data/seed-*.apex`.**

## Run locally

```bash
npm install
cp .dev.vars.example .dev.vars     # set CLIENT_ID / CLIENT_SECRET for local dev
npm run dev                        # wrangler dev on http://localhost:8787
```

Smoke test:

```bash
TOK=$(curl -s -X POST localhost:8787/oauth/token \
  -d 'grant_type=client_credentials&client_id=<id>&client_secret=<secret>&scope=read' | jq -r .access_token)

curl -s -X POST localhost:8787/policy-advisor \
  -H "authorization: Bearer $TOK" -H 'content-type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' | jq
```

## Deploy (facilitators)

```bash
npx wrangler login
npx wrangler secret put CLIENT_ID       # the shared workshop client id
npx wrangler secret put CLIENT_SECRET   # a strong random secret
npx wrangler deploy
```

`wrangler deploy` prints the live host, e.g.
`https://riskonnect-policy-advisor.<your-subdomain>.workers.dev`. Give participants:

- MCP endpoint: `https://<host>/policy-advisor`
- Token endpoint: `https://<host>/oauth/token`
- `CLIENT_ID` / `CLIENT_SECRET` and scope `read`

Then substitute the real host for `YOUR-DOMAIN` in the credential metadata (or have participants do
it in Setup before the Module 2 smoke test).

## Security notes

- **Secrets are never committed.** `CLIENT_ID` / `CLIENT_SECRET` come from `wrangler secret` (prod) or
  `.dev.vars` (local, gitignored). The Worker refuses to issue tokens if they are unset.
- Token signature uses a constant-time comparison; expired and tampered tokens are rejected.
- This is a **mock** for training. It has no real regulatory authority and returns canned data.
