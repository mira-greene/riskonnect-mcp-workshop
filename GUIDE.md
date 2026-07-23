# Riskonnect Policy Agent Workshop — Build Guide

You will stand up the **Policy Agent** Agentforce agent in your assigned org, connect it to the
shared **mock Riskonnect MCP server**, and iterate on its behavior. This guide offers **two parallel
tracks** for each manual step: **CLI** (command-line focused) and **UI** (Setup UI focused) — choose
the track that matches your workflow.

**Prereqs:** the `sf` CLI, an assigned pre-configured org, and the client id/secret your facilitator
hands out. Copy `.env.example` to `.env` and set `ORG_ALIAS` to your org alias. All scripts accept
`--org <alias>` if you prefer.

**Time estimate:** ~2 hours (Modules 0–5).

---

## Module 0 — Comprehend (Claude Code, optional but recommended)

Open Claude Code inside this repo. First, install the two workshop plugins, then use them to
reverse-engineer the agent.

### 0a — Install the plugins

In Claude Code, install both plugins. The exact marketplace commands:

- **`agentforce-adlc`** — the Agent Development Life Cycle toolkit. Provides the skills you'll use to
  build, iterate on, and test the agent.
  ```
  /plugin marketplace add SalesforceAIResearch/agentforce-adlc
  /plugin install agentforce-adlc@agentforce-adlc
  ```
- **`sf-mcp-partner-toolkit`** — the Salesforce MCP integration toolkit. Provides the skills you'll use
  to wire and troubleshoot the connection to the mock MCP server.
  ```
  /plugin marketplace add mvogelgesang/sf-mcp-partner-toolkit
  /plugin install sf-mcp-partner-toolkit@mvogelgesang-plugins
  ```
  > Provenance note: `sf-mcp-partner-toolkit` is a public community repo
  > (`github.com/mvogelgesang/sf-mcp-partner-toolkit`), not an official Salesforce marketplace.

After install, confirm a skill is available: `/developing-agentforce`.

### The skills, and when to use each

| Skill | Plugin | What it does | Use it in |
|---|---|---|---|
| **`developing-agentforce`** | agentforce-adlc | Build, edit, debug, preview, and publish `.agent` bundles; the core authoring loop. | Modules 0, 5 |
| **`testing-agentforce`** | agentforce-adlc | Write and run structured agent test specs (AiEvaluationDefinition); interpret results. | Module 5 (optional) |
| **`diagnose-connection`** | sf-mcp-partner-toolkit | Troubleshoot MCP connectivity — installs MCP Workbench and walks an error taxonomy. | Module 2, if the smoke test fails |
| **`validate-end-to-end`** | sf-mcp-partner-toolkit | Confirm the MCP integration works from Agentforce: discovery → schema → agent invocation. | Module 5 |

> The other skills in these plugins (`scaffold-mcp-integration`, `deploy-and-configure`,
> `observing-agentforce`, etc.) generate or deploy MCP metadata that this repo **already ships** — you
> don't need them for the workshop build. Stick to the four above.

### 0b — Reverse-engineer the agent

With `developing-agentforce` available, run these prompts in Claude Code:

- "Locate the AiAuthoringBundle directory. Read the .agent file and produce an Agent Spec in plain English."
- "Generate a Mermaid Subagent Map diagram for this agent."
- "What does the policy_analysis subagent do, and what instructions guard its behavior?"

---

## Module 1 — Deploy

Run the deployment scripts:

```bash
./scripts/01-check-env.sh          # tooling + authenticated org
./scripts/02-deploy.sh             # deploys all source (incl. the agent bundle)
./scripts/03-assign-perms.sh       # assigns the permission set to you
```

Then verify: `sf org open` → Setup → Object Manager → confirm **Policy_Gap__c** and
**Policy_Document__c** appear.

> **Troubleshooting — deploy fails on retry with "DeveloperName 'PolicyAgent' is already in use by a
> Bot Definition."** A previous partial deploy left an orphaned authoring bundle that reserved the agent's
> name, even though no agent shows up in the org. It is invisible to a normal Bot query — find it with
> `sf org list metadata -m AiAuthoringBundle -o <org> --json` (look for `PolicyAgent_1` or similar).
> Confirm no real agent exists (`SELECT DeveloperName FROM BotDefinition` and `… FROM GenAiPlannerDefinition`
> both return 0 rows), then remove the orphan and redeploy:
> ```bash
> sf project delete source --metadata "AiAuthoringBundle:PolicyAgent_1" -o <org> --no-prompt
> ./scripts/02-deploy.sh
> ```

---

## Module 2 — Connect (🔴 the credential, then verify)

The package deployed the credential **shells**. You add the secret-bearing principal by hand — that
part never ships in metadata. **Choose your track: CLI or UI.**

### 🔴 Checkpoint 2a — add the Named Principal to the existing External Credential

The External Credential `RiskonnectPolicyAdvisor` already exists — do **not** create a new one. You
are adding a **principal** to it.

#### **Track A: CLI**

Use the Salesforce CLI to create the Named Principal:

```bash
# First, retrieve the External Credential ID (query ExternalCredential — NOT NamedCredential; they are different objects)
sf data query --query "SELECT Id, DeveloperName FROM ExternalCredential WHERE DeveloperName = 'RiskonnectPolicyAdvisor'" --target-org <alias> --json

# Note the Id, then create the principal (replace <EXTERNAL_CRED_ID> and <CLIENT_ID>/<CLIENT_SECRET>)
sf data create record --sobject ExternalCredentialPrincipal \
  --values "ExternalCredentialId=<EXTERNAL_CRED_ID> PrincipalName=MCPAuthentication PrincipalType=NamedPrincipal SequenceNumber=1 AuthenticationProtocol=Oauth" \
  --target-org <alias>

# Now add the OAuth parameters (replace <PRINCIPAL_ID> with the ID returned above)
sf data create record --sobject ExternalCredentialParameter \
  --values "ExternalCredentialPrincipalId=<PRINCIPAL_ID> ParameterName=client_id ParameterValue=<CLIENT_ID>" \
  --target-org <alias>

sf data create record --sobject ExternalCredentialParameter \
  --values "ExternalCredentialPrincipalId=<PRINCIPAL_ID> ParameterName=client_secret ParameterValue=<CLIENT_SECRET>" \
  --target-org <alias>
```

> **Why via CLI?** This is the only way to programmatically set secret-bearing principals. The
> principal name **must** be `MCPAuthentication` — the permset grant references it by this exact name.

#### **Track B: UI**

Setup → Security → **Named Credentials** → **External Credentials** tab → open **`RiskonnectPolicyAdvisor`**
(it already exists — do **not** create a new one).

In **Principals**, click **New**:
- **Parameter Name:** `MCPAuthentication`
- **Sequence Number:** `1`
- **Identity Type:** Named Principal
- **Authentication Protocol:** OAuth 2.0
- **Client ID / Client Secret:** the values from your facilitator

Save.

> **Why:** the External Credential, Named Credential, and the OAuth protocol/token URL all deploy. The
> **principal (the secret) cannot be packaged.** The permset grant references the principal by the
> exact name `RiskonnectPolicyAdvisor-MCPAuthentication`, so the principal name must be `MCPAuthentication`.

---

### 🔴 Checkpoint 2b — grant External Credential Principal Access on the permission set

#### **Track A: CLI**

```bash
# First, find the permission set ID
sf data query --query "SELECT Id, Name FROM PermissionSet WHERE Name = 'Riskonnect_Policy_Agent_Perm_Set'" --target-org <alias> --json

# Find the External Credential Principal ID
sf data query --query "SELECT Id FROM ExternalCredentialPrincipal WHERE PrincipalName = 'MCPAuthentication'" --target-org <alias> --json

# Create the grant (replace <PERMSET_ID> and <PRINCIPAL_ID>)
sf data create record --sobject SetupEntityAccess \
  --values "ParentId=<PERMSET_ID> SetupEntityId=<PRINCIPAL_ID>" \
  --target-org <alias>
```

> **Why:** this grant **silently drops on deploy** if the principal didn't exist at deploy time, and a
> redeploy won't re-add it. The merge-field auth header resolves empty without it.

#### **Track B: UI**

Setup → Users → **Permission Sets** → open **`Riskonnect_Policy_Agent_Perm_Set`** →
**External Credential Principal Access** → **Edit** → enable
**`RiskonnectPolicyAdvisor - MCPAuthentication`** → Save.

> **Why:** this grant **silently drops on deploy** if the principal didn't exist at deploy time, and a
> redeploy won't re-add it. The merge-field auth header resolves empty without it.

---

### Install the MCP Workbench (diagnostic, optional)

Install the unmanaged package (replace `<org>` with your My Domain host, or paste the path into the
browser while logged in):

```
/packaging/installPackage.apexp?p0=04tHs000000iSjcIAE
```

It sends real JSON-RPC through the Named Credential and gives structured error diagnostics — keep it
handy if the next step fails.

---

### Grant the Platform Integration User (run after Workbench is installed)

```bash
sf apex run --file scripts/apex/assign-piu-permset.apex --target-org <alias>
```

Look for `PIU_RESULT=✔` (or `ℹ already assigned`).

> **Why:** the **agent's** runtime MCP callout runs as the Platform Integration User, which also needs
> `Riskonnect_Policy_Agent_Perm_Set`. Skip this and your admin callout test passes but the wired agent
> returns "no data."

---

### Verify the callout

```bash
./scripts/04-smoke-test.sh --org <alias>
```

Expected: `200` + a body listing **3 tools**. Troubleshooting:

| Symptom | Fix |
|---|---|
| 401 / 403 | EC Principal Access not granted on `Riskonnect_Policy_Agent_Perm_Set` (Checkpoint 2b) |
| 404 | Named Credential URL wrong / trailing-slash mismatch |
| "Unauthorized endpoint" | Re-save the Named Credential to refresh the Remote Site Setting |
| empty body / INVALID_AUTH_HEADER | "Generate Authorization Header" is off on the NC |

> **Stuck?** Run the **`diagnose-connection`** skill (sf-mcp-partner-toolkit) in Claude Code — it walks
> the MCP error taxonomy and confirms MCP Workbench is set up to pinpoint the failure.

---

## Module 3 — Register the MCP tools (🔴)

Register the 3 MCP tools so Agentforce can discover and invoke them. **Choose your track: CLI or UI.**

### 🔴 Checkpoint 3 — Add the 3 tools

#### **Track A: CLI**

Use the `sf agent mcp` command group (**Developer Preview**), which manages MCP servers as entries in
the **API Catalog**. Flags below are verified against Salesforce CLI **2.144.6** — confirm your build
with `sf version` and `sf agent mcp --help` (run `npm install -g @salesforce/cli@latest` if the group
is missing). Every `sf agent mcp` command prints a Developer-Preview warning and may change between
releases; dry-run in your own org first.

> ⚠️ **The CLI track registers the server differently than the UI track — read this first.**
> `sf agent mcp create` does **not** reference the deployed `RiskonnectPolicyAdvisor` Named Credential.
> It creates its **own** API Catalog registration from the server URL plus inline OAuth, and OAuth
> requires an **identity provider already configured in the org**, passed by name to
> `--identity-provider`. So the CLI track needs that identity provider set up first (see the
> prerequisite below); the UI track (Track B) reuses the Named/External Credential you configured in
> Module 2 and needs no extra setup. **Pick one track and stay on it.** If the prerequisite below
> doesn't apply cleanly to your org, use **Track B** — it's fully supported.

> **🔧 Track A prerequisite — the `--identity-provider` value.**
> `sf agent mcp create --auth-type OAUTH` requires `--identity-provider <NAME>`, where `<NAME>` is the
> **DeveloperName of an Auth. Provider** in your org configured for the OAuth client-credentials flow
> against the mock server's token endpoint (`.../oauth/token`). Confirm what already exists before
> creating anything:
> ```bash
> sf data query --query "SELECT Id, DeveloperName FROM AuthProvider" --target-org <alias>
> ```
> If a suitable provider exists, pass its `DeveloperName` to `--identity-provider`. If none exists,
> create one in **Setup → Security → Auth. Providers → New**, pointing its token endpoint at
> `https://riskonnect-policy-advisor.mira-greene.workers.dev/oauth/token` with the workshop
> `client_id`/`client_secret` and scope `read`, then use its DeveloperName.
> ⚠️ **This step is not yet verified end-to-end** — `sf agent mcp` is Developer Preview and the exact
> identity-provider construct it accepts may differ by release. If `create` rejects the provider or
> discovery returns nothing, **switch to Track B (UI)**; it does not need an Auth Provider and is the
> guaranteed path. Do not burn workshop time fighting Track A — Track B produces the identical result.

```bash
# 1. Register the MCP server in the API Catalog. `create` also auto-discovers the server's assets.
#    --server-url and (for OAuth) --identity-provider/--client-id/--client-secret/--scope are required.
#    Pass the client secret via stdin ("-") to keep it out of shell history.
sf agent mcp create \
  --name RiskonnectPolicyAdvisor \
  --label "Riskonnect Policy Advisor" \
  --server-url "https://riskonnect-policy-advisor.mira-greene.workers.dev/policy-advisor" \
  --auth-type OAUTH \
  --identity-provider <AUTH_PROVIDER_NAME> \
  --client-id <CLIENT_ID> \
  --client-secret - \
  --scope read \
  --target-org <alias>
# → note the returned MCP server ID (looks like 0XSxx0000000001); you need it below.

# 2. (Optional) Refresh the live assets the server advertises
sf agent mcp fetch --mcp-server-id <MCP_SERVER_ID> --target-org <alias>

# 3. List discovered assets to see their exact names, kind, and active/available state
sf agent mcp asset list --mcp-server-id <MCP_SERVER_ID> --target-org <alias>

# 4. Activate the 3 tools. `asset replace` is a FULL replacement — pass the complete desired set.
#    Asset names are the server's tool names as discovered in step 3 (verify them there first).
sf agent mcp asset replace --mcp-server-id <MCP_SERVER_ID> --target-org <alias> --assets '{
  "assets": [
    { "name": "get_policy_details",        "active": true },
    { "name": "analyze_regulatory_gap",    "active": true },
    { "name": "recommend_policy_updates",  "active": true }
  ]
}'

# 5. Verify
sf agent mcp list --target-org <alias>
sf agent mcp asset list --mcp-server-id <MCP_SERVER_ID> --target-org <alias>
```

Expected after step 5: the server appears in `agent mcp list`, and `asset list` shows the 3 tools
`get_policy_details`, `analyze_regulatory_gap`, `recommend_policy_updates` as active and available as
agent actions.

> **Notes.** Discovery returns nothing until the OAuth path authenticates, so the Auth Provider and
> client id/secret must be valid. `asset replace` removes any asset not in the set you pass — always
> `asset list` (or `fetch`) first and include the full desired set. Confirm the exact `--assets` name
> values against step 3's output before running; the JSON above assumes the tool names match. If any
> subcommand or flag is missing in your CLI, use **Track B (UI)**.

#### **Track B: UI**

Setup → Quick Find **MCP Servers** → open **`RiskonnectPolicyAdvisor`** → **Manage Tools** → **Add Tool**
for each of the 3 tools → confirm. All 3 should show **Active** with populated input/outputSchema.

The 3 tools to add:
1. `get_policy_details`
2. `analyze_regulatory_gap`
3. `recommend_policy_updates`

> **Notes:** the tool list won't load until Checkpoint 2a is done. Salesforce **caches** the schema —
> after any server schema change, **Re-fetch schema** before re-adding.

---

### Optional validation (Claude Code)

Run this in Claude Code to validate conformance:
> "Read the 3 MCP tool schemas registered for RiskonnectPolicyAdvisor. Validate each against: (1) outputSchema is a valid JSON Schema describing the response; (2) the server returns 202 on notifications; (3) all I/O fields use JSON primitives. Report violations and why each matters."

---

## Module 4 — Wire & Activate (🔴 ORDER MATTERS)

> ## ⛔ Publish BEFORE wiring the MCP actions in the UI — never after.
> `sf agent publish` from source **reverts the in-org MCP tool bindings every time.** If you wire the
> actions first and then publish, the bindings are wiped (the "no data" regression). Always: **publish →
> wire/re-wire actions in Agent Builder → activate.**

**Choose your track: CLI or UI.**

### Step 1: Publish the agent bundle

Find the agent's API name:

```bash
sf project list metadata --metadata-type AiAuthoringBundle --target-org <alias>
```

Validate, then publish:

```bash
sf agent validate authoring-bundle --api-name PolicyAgent --target-org <alias>
sf agent publish authoring-bundle --api-name PolicyAgent --target-org <alias>
```

---

### Step 2: Wire the 3 MCP actions to topics

> **Both tracks converge here — this step is UI-only.** There is no supported `sf` command to attach
> an individual action/tool to an agent topic. Agent capabilities come from the authoring bundle plus
> `sf agent publish`; the *binding* of registered MCP tools to topics is done in Agent Builder. (This
> is also why the ⛔ order above matters: `sf agent publish` re-runs from source and resets these
> in-org bindings, so you wire them **after** publishing.) CLI-track participants: you did the CLI work
> in Module 3 (registering the server/tools) — this one step is in the UI for everyone.

Setup → Agentforce → Agents → open **Policy Agent** → for each topic:

1. **Policy Analysis** topic:
   - **This Topic's Actions → Add Action → MCP → RiskonnectPolicyAdvisor**:
     - Add `get_policy_details`
     - Add `recommend_policy_updates`

2. **Regulatory Gap Check** topic:
   - **This Topic's Actions → Add Action → MCP → RiskonnectPolicyAdvisor**:
     - Add `analyze_regulatory_gap`

Save after each topic.

---

### Step 3: Activate the agent

#### **Track A: CLI**

```bash
sf agent activate --api-name PolicyAgent --target-org <alias>
```

#### **Track B: UI**

Setup → Agentforce → Agents → open **Policy Agent** → **Activate** button (top right).

---

## Module 5 — Verify & Iterate

### Verify the agent works

Agent Builder → **Conversation Preview** → try these prompts:

1. "Show me the current data privacy policy"
2. "Analyze our data privacy policy against GDPR Article 30"
3. "What updates should we make to our incident response policy for the new SEC cyber rules?"

Expected: **real data** from the MCP server (policy details, gap analysis, recommendations).

If "no data," re-check in this order: EC grant (2b) → Platform Integration User grant → action wiring
(Module 4) — before suspecting the agent.

> **Confirm the full chain** with the **`validate-end-to-end`** skill (sf-mcp-partner-toolkit) — it
> checks tool discovery, schema correctness, and live agent invocation in one pass.

---

### The inner loop — edit behavior with NO publish

Now iterate on the agent without re-publishing:

1. Open `force-app/main/default/aiAuthoringBundles/PolicyAgent/PolicyAgent.agent`
2. Add an instruction to a subagent (e.g. "Always cite the specific regulation article number when identifying gaps.")
3. Validate:
   ```bash
   sf agent validate authoring-bundle --api-name PolicyAgent --target-org <alias>
   ```
4. Preview with live actions:
   ```bash
   sf agent preview start --use-live-actions --authoring-bundle PolicyAgent --target-org <alias>
   # capture the sessionId, then:
   sf agent preview send --authoring-bundle PolicyAgent --session-id <sessionId> \
     -u "Analyze our data privacy policy against GDPR Article 30" --target-org <alias>
   ```

> **This is the inner loop: edit `.agent` → validate → preview `--use-live-actions`. No publish needed.**
> Lean on the **`developing-agentforce`** skill here — it understands the `.agent` syntax and the
> validate/preview commands, and can diagnose validation errors.

---

### Optional extensions (if time remains)

- Add a second instruction to a different subagent and re-run the inner loop.
- Seed demo data: `./scripts/05-seed-data.sh` — creates 3 Policy_Gap__c records.
- Use the **`testing-agentforce`** skill (agentforce-adlc) to write a structured test spec for the
  agent and run it — a glimpse of the regression-testing side of the ADLC.
- Ask Claude Code: "Score this AiAuthoringBundle against the Agentforce 100-point rubric and flag safety review issues."

---

## Troubleshooting Quick Reference

| Symptom | Most likely cause | Fix |
|---|---|---|
| Deploy fails "DeveloperName already in use" | Orphaned AiAuthoringBundle | `sf org list metadata -m AiAuthoringBundle`, then `sf project delete source --metadata "AiAuthoringBundle:<name>"` |
| Smoke test returns 401/403 | EC Principal Access not granted | Module 2, Checkpoint 2b — grant on permission set |
| Smoke test returns 404 | Named Credential URL wrong | Re-check the URL in the Named Credential matches the mock server endpoint |
| MCP tools list is empty | Principal not created yet | Module 2, Checkpoint 2a — create the principal first |
| Agent returns "no data" | Action wiring or PIU grant missing | Re-check Module 4 (action wiring) and Module 2 (PIU grant) |
| Preview fails "validation errors" | `.agent` syntax error | Run `sf agent validate` to see the specific error |

For deeper diagnosis, use the **`diagnose-connection`** skill (sf-mcp-partner-toolkit) in Claude Code.

---

## Summary

You've built a complete MCP-powered Agentforce agent in ~2 hours:
- Connected Salesforce to an external MCP server using Named Credentials and External Credentials
- Registered 3 MCP tools and wired them as Agentforce actions
- Learned the inner loop: edit `.agent` → validate → preview (no publish)
- Experienced both CLI and UI workflows for every manual checkpoint

**Next steps:**
- Apply this pattern to your own Riskonnect or partner integrations
- Explore the ADLC skills for testing, observing, and iterating on agents
- Review the mock MCP server source to understand how to build your own MCP-compliant service
