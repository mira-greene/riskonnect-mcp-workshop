# Participant Org Requirements

What each participant's Salesforce org must satisfy **before** the workshop. Verified against a
fresh scratch org (`riskonnect-clean`) created from `config/agentforce-scratch-def.json` on
2026-07-23 with Salesforce CLI **2.144.6**.

`scripts/01-check-env.sh --org <alias>` probes most of these automatically — run it first.

---

## 1. Org type & edition

| Requirement | Value | Why |
|---|---|---|
| Edition | Developer, or a sandbox/scratch with Agentforce | Agentforce + Einstein must be available |
| API version | **65.0 or higher** | `AiAuthoringBundle` (the Agent Script bundle) was introduced in API 65.0; the repo builds at 67.0 |
| Agentforce | Enabled (`agentPlatformSettings.enableAgentPlatform`) | Publishing/running the Policy Agent |
| Einstein / GenAI | Enabled (`einsteinGptSettings.enableEinsteinGptPlatform`) | Agent reasoning |

A ready-to-use scratch definition is committed at `config/agentforce-scratch-def.json`. Facilitators
handing out scratch orgs can create them with:

```bash
sf org create scratch --definition-file config/agentforce-scratch-def.json \
  --alias <participant-alias> --target-dev-hub <devhub> --duration-days 7
```

> **Scratch-org note:** `sf org create scratch --json` no longer prints the org password. If a
> participant needs a UI login: `sf org generate password --target-org <alias>`.

---

## 2. Tooling (local machine)

| Tool | Minimum | Check |
|---|---|---|
| Salesforce CLI (`sf`) | **2.144.6+** | `sf version` |
| `jq` | any recent | `jq --version` |
| Git | any | `git --version` |

- Use `sf`, never the deprecated `sfdx`.
- If `sf agent mcp` is missing (Module 3 Track A), update: `npm install -g @salesforce/cli@latest`.

---

## 3. Feature availability (advisory — surfaced by 01-check-env.sh)

| Probe | Needed for | If missing |
|---|---|---|
| Agentforce enabled (BotDefinition queryable) | All agent modules | Org can't run the workshop — get an Agentforce-enabled org |
| Platform Integration User exists | Module 2 callout | Assign the Platform Integration User (see GUIDE Module 2) |
| `sf agent mcp` command group present | Module 3 **Track A (CLI)** | Update the CLI, or use **Track B (UI)** |
| At least one Auth Provider | Module 3 **Track A (CLI)** only | Create one (GUIDE Module 3 prerequisite), or use **Track B (UI)** |

> **A fresh org has NO Auth Providers.** Module 3 Track A (CLI) requires one because
> `sf agent mcp create --auth-type OAUTH` needs `--identity-provider <AuthProviderName>` — and the
> only `auth-type` values the CLI accepts are `OAUTH` and `NO_AUTH` (there is no API-key path). Since
> the mock server requires OAuth, **Track A genuinely needs an Auth Provider.** Participants who can't
> or don't want to create one should use **Track B (UI)**, which reuses the Named/External Credential
> from Module 2 and needs no Auth Provider. Both tracks produce the identical result.

---

## 4. Developer Preview caveat

`sf agent mcp` is **Developer Preview** on CLI 2.144.6 — every invocation prints a preview warning and
flags/behavior may change between releases. The workshop's Track A commands are verified against
2.144.6 (all documented flags — `name`, `label`, `server-url`, `auth-type`, `identity-provider`,
`client-id`, `client-secret`, `scope`, and `asset replace --assets` — exist and match). If a
participant's CLI differs and a flag is rejected, fall back to **Track B (UI)**.

---

## 5. What the facilitator provides (not an org requirement)

- The mock MCP server URL (`https://riskonnect-policy-advisor.mira-greene.workers.dev`) — a shared
  Cloudflare Worker. Participants do **not** stand up their own.
- The workshop `client_id` / `client_secret` for the OAuth token endpoint (entered by each participant
  in Module 2; never committed to the repo).

> **Shared-endpoint note:** all participants hit the same Worker. It's a mock with a small in-memory
> dataset and no per-participant state, so concurrent use is fine, but a facilitator running a large
> cohort should sanity-check the Worker is reachable (`/health`) before the session.

---

## Pre-workshop checklist

- [ ] Org is Agentforce + Einstein enabled, API ≥ 65.0
- [ ] `sf version` ≥ 2.144.6; `jq` and `git` installed
- [ ] `sf org login web` (or scratch org created) and org set as default or aliased
- [ ] `./scripts/01-check-env.sh --org <alias>` run — all checks pass (Auth Provider warning is OK if using Track B)
- [ ] Facilitator has confirmed the mock server `/health` responds
