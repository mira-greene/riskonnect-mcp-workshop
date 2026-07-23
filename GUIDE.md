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
# First, retrieve the External Credential ID
sf data query --query "SELECT Id, DeveloperName FROM NamedCredential WHERE DeveloperName = 'RiskonnectPolicyAdvisor'" --target-org <alias> --json

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

Use the Salesforce CLI with the MCP plugin (requires `@salesforce/plugin-mcp` installed):

```bash
# Install the MCP plugin if not already installed
sf plugins install @salesforce/plugin-mcp

# Fetch the tool schemas from the MCP server
sf mcp fetch-tools --named-credential RiskonnectPolicyAdvisor --target-org <alias>

# Register each tool (the command auto-populates inputSchema and outputSchema)
sf mcp register-tool --named-credential RiskonnectPolicyAdvisor --tool-name get_policy_details --target-org <alias>
sf mcp register-tool --named-credential RiskonnectPolicyAdvisor --tool-name analyze_regulatory_gap --target-org <alias>
sf mcp register-tool --named-credential RiskonnectPolicyAdvisor --tool-name recommend_policy_updates --target-org <alias>

# Verify all 3 are registered
sf mcp list-tools --named-credential RiskonnectPolicyAdvisor --target-org <alias>
```

> **Notes:** the tool list won't load until Checkpoint 2a is done. Salesforce **caches** the schema —
> after any server schema change, re-run `fetch-tools` before re-registering.

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

#### **Track A: CLI**

Use the Salesforce CLI to wire MCP actions to agent topics:

```bash
# First, find the agent's GenAiPlannerDefinition ID
sf data query --query "SELECT Id, DeveloperName FROM GenAiPlannerDefinition WHERE DeveloperName = 'PolicyAgent'" --target-org <alias> --json

# Find the topic IDs (PolicyAgent has 2 topics: Policy_Analysis and Regulatory_Gap_Check)
sf data query --query "SELECT Id, Label FROM GenAiPlannerTopic WHERE GenAiPlannerDefinitionId = '<AGENT_ID>'" --target-org <alias> --json

# Find the MCP tool IDs
sf data query --query "SELECT Id, DeveloperName FROM ExternalServiceAction WHERE DeveloperName IN ('get_policy_details', 'analyze_regulatory_gap', 'recommend_policy_updates')" --target-org <alias> --json

# Wire the actions to topics (replace <TOPIC_ID> and <ACTION_ID>)
# Policy_Analysis topic gets: get_policy_details, recommend_policy_updates
sf data create record --sobject GenAiPlannerTopicAction \
  --values "GenAiPlannerTopicId=<POLICY_ANALYSIS_TOPIC_ID> ActionId=<GET_POLICY_DETAILS_ACTION_ID>" \
  --target-org <alias>

sf data create record --sobject GenAiPlannerTopicAction \
  --values "GenAiPlannerTopicId=<POLICY_ANALYSIS_TOPIC_ID> ActionId=<RECOMMEND_POLICY_UPDATES_ACTION_ID>" \
  --target-org <alias>

# Regulatory_Gap_Check topic gets: analyze_regulatory_gap
sf data create record --sobject GenAiPlannerTopicAction \
  --values "GenAiPlannerTopicId=<REGULATORY_GAP_CHECK_TOPIC_ID> ActionId=<ANALYZE_REGULATORY_GAP_ACTION_ID>" \
  --target-org <alias>
```

> **Why CLI?** This is the programmatic way to wire actions without clicking through Agent Builder. The
> topic-action bindings are metadata but can be managed via Tooling API.

#### **Track B: UI**

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
