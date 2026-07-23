# Riskonnect Policy Agent Workshop

[![GitHub](https://img.shields.io/badge/GitHub-riskonnect--mcp--workshop-blue?logo=github)](https://github.com/mira-greene/riskonnect-mcp-workshop)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Clone this repo to build the **Policy Agent** Agentforce agent in your assigned org and connect it
to a shared mock **MCP server** for policy gap analysis and regulatory compliance monitoring.

## 👉 Start here: [**GUIDE.md** — the full step-by-step build guide](./GUIDE.md)

Everything below is orientation. The detailed, module-by-module instructions live in
**[GUIDE.md](./GUIDE.md)** — open it and follow it top to bottom.

## What you're building

An Agentforce agent that assists policy managers and compliance teams by analyzing gaps between
existing organizational policies and new regulations, then recommending specific policy updates. The
agent calls a Riskonnect Policy Advisory service over the **Model Context Protocol (MCP)** to access
regulatory intelligence and policy analysis tools. The MCP server is **shared and hosted** — you do
not deploy it.

## Prerequisites

- **Salesforce CLI** (`sf`) — https://developer.salesforce.com/tools/salesforcecli
- An **assigned, pre-configured org** (Agentforce enabled). Log in: `sf org login web --alias <your-alias>`
- **Client ID / Client Secret** for the MCP credential — provided by your facilitator.
- **Claude Code** (optional but recommended), with the **`agentforce-adlc`** and **`sf-mcp-partner-toolkit`**
  plugins — you install these in GUIDE.md Module 0 (the guide describes each skill and when to use it).

## Quick start

```bash
git clone https://github.com/mira-greene/riskonnect-mcp-workshop.git
cd riskonnect-mcp-workshop
cp .env.example .env          # set ORG_ALIAS to your org alias
./scripts/01-check-env.sh
./scripts/02-deploy.sh
./scripts/03-assign-perms.sh
# then follow GUIDE.md from Module 2 (the credential is a manual step)
```

`04-smoke-test.sh` (verify the callout) and `05-seed-data.sh` (load demo records) run later, at the
points GUIDE.md calls for them — after the credential exists. All scripts accept `--org <alias>` if
you don't use `.env`.

## The happy path (6 modules, ~2 hours)

0. **Comprehend** — use Claude Code to reverse-engineer the agent.
1. **Deploy** — push source, assign permission sets.
2. **Connect** 🔴 — add the MCP credential principal (two tracks: CLI or UI), grant access, verify the callout.
3. **Register** 🔴 — register the 3 MCP tools (two tracks: CLI or UI).
4. **Wire & Activate** 🔴 — publish, wire actions, activate (two tracks: CLI or UI, order matters).
5. **Verify & Iterate** — test the agent, edit behavior, re-test.

🔴 = manual checkpoint (the steps that silently break a build — GUIDE.md explains each).

## Repo layout

```
force-app/   the agent bundle, Named Credential shells, External Credential, permission sets, custom objects
scripts/     numbered helpers (01-check-env, 02-deploy, 03-assign-perms, 04-smoke-test, 05-seed-data)
  apex/      test_callout.apex, assign-piu-permset.apex
  lib/       common.sh (shared bash helpers)
data/        seed-policies.apex + seed-gaps.apex (seed payloads for Policy_Document__c / Policy_Gap__c)
mcp-server/  source for the shared mock MCP server (Cloudflare Worker) — facilitators deploy; participants don't
config/      scratch-org def (optional — participants use pre-configured orgs in the workshop)
GUIDE.md     the full build guide with CLI + UI tracks side-by-side — start here
```

## The mock MCP server

The Riskonnect Policy Advisory data is served by a small **Cloudflare Worker** that speaks MCP. It's
**shared and hosted** — as a participant you do not deploy or run it. The Worker source lives in
[`mcp-server/`](./mcp-server/) (see its [README](./mcp-server/README.md) for the endpoints, the mock
dataset, and facilitator deploy steps).

> ⚠️ **The credential metadata ships pointing at the live shared Worker host below.** If your
> facilitator stands up their own Worker, they'll give you a different host — update the Named
> Credential URL and the External Credential token URL to match before the smoke test in
> **GUIDE.md Module 2**, otherwise every callout returns 404.

These are the values you'll confirm/enter when you wire the credential in **GUIDE.md Module 2**:

| What | Value |
|---|---|
| Named Credential URL (MCP endpoint) | `https://riskonnect-policy-advisor.mira-greene.workers.dev/policy-advisor` |
| External Credential auth protocol | OAuth 2.0 — Client Credentials |
| Token endpoint | `https://riskonnect-policy-advisor.mira-greene.workers.dev/oauth/token` |
| Scope | `read` |
| Client ID / Secret | provided by your facilitator (entered in the UI or via CLI; never in this repo) |

> **Facilitators / maintainers only:** the Worker is managed in Cloudflare (service
> `riskonnect-policy-advisor`, production). The dashboard URL will be provided by the workshop
> mediator; participants don't need it.

## The three MCP tools

1. **`get_policy_details`** — retrieve current policy document metadata and content by policy ID
2. **`analyze_regulatory_gap`** — compare a policy against a regulation to identify gaps
3. **`recommend_policy_updates`** — generate specific policy language recommendations to close gaps

## Notes

- **Secrets never live in this repo** — the client id/secret is entered in the Salesforce UI or via
  CLI only.
- The optional `config/` scratch-org def enables basic Salesforce DX features; Agentforce must be
  enabled separately by your facilitator.
- Custom objects: **`Policy_Gap__c`** (tracks identified gaps) and **`Policy_Document__c`** (catalog
  of organizational policies).

## Contributing

This workshop is open source under the MIT License. Contributions welcome! Please file issues or PRs at:
https://github.com/mira-greene/riskonnect-mcp-workshop

## License

MIT License - see [LICENSE](LICENSE) file for details.
