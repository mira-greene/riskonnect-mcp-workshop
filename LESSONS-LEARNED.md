# Riskonnect MCP Workshop — Lessons Learned

This document captures common issues and their solutions for workshop facilitators and participants.

---

## Issue: "DeveloperName 'PolicyAgent' is already in use by a Bot Definition"

**Symptom:** Deploy fails on retry with this error, but no agent shows up in the org.

**Root cause:** A previous partial deploy left an orphaned `AiAuthoringBundle` that reserved the agent's name. It is invisible to a normal Bot query.

**Solution:**

1. Find the orphan:
   ```bash
   sf org list metadata -m AiAuthoringBundle -o <org> --json
   ```
   Look for `PolicyAgent_1` or similar.

2. Confirm no real agent exists:
   ```bash
   sf data query --query "SELECT DeveloperName FROM BotDefinition" -o <org>
   sf data query --query "SELECT DeveloperName FROM GenAiPlannerDefinition" -o <org>
   ```
   Both should return 0 rows.

3. Remove the orphan:
   ```bash
   sf project delete source --metadata "AiAuthoringBundle:PolicyAgent_1" -o <org> --no-prompt
   ```

4. Redeploy:
   ```bash
   ./scripts/02-deploy.sh --org <org>
   ```

---

## Issue: Smoke test returns 401 or 403

**Symptom:** `./scripts/04-smoke-test.sh` returns 401 or 403.

**Root cause:** External Credential Principal Access not granted on the permission set.

**Solution:**

Re-do **GUIDE.md Module 2, Checkpoint 2b**:

- **UI track:** Setup → Users → Permission Sets → `Riskonnect_Policy_Agent_Perm_Set` → External Credential Principal Access → Edit → enable `RiskonnectPolicyAdvisor - MCPAuthentication` → Save.

- **CLI track:**
  ```bash
  sf data query --query "SELECT Id, Name FROM PermissionSet WHERE Name = 'Riskonnect_Policy_Agent_Perm_Set'" --target-org <alias> --json
  sf data query --query "SELECT Id FROM ExternalCredentialPrincipal WHERE PrincipalName = 'MCPAuthentication'" --target-org <alias> --json
  sf data create record --sobject SetupEntityAccess --values "ParentId=<PERMSET_ID> SetupEntityId=<PRINCIPAL_ID>" --target-org <alias>
  ```

---

## Issue: Smoke test returns 404

**Symptom:** `./scripts/04-smoke-test.sh` returns 404.

**Root cause:** Named Credential URL mismatch or trailing-slash issue.

**Solution:**

1. Check the Named Credential URL:
   ```bash
   sf data query --query "SELECT Url FROM NamedCredential WHERE DeveloperName = 'RiskonnectPolicyAdvisor'" -o <org>
   ```

2. Confirm it matches the workshop MCP server endpoint exactly (no trailing slash unless the server expects one).

3. If wrong, update via Setup → Named Credentials → edit `RiskonnectPolicyAdvisor` → correct the URL → Save.

---

## Issue: MCP tools list is empty in Setup

**Symptom:** Setup → MCP Servers → RiskonnectPolicyAdvisor → Manage Tools shows no tools.

**Root cause:** The Named Principal has not been created yet (Module 2, Checkpoint 2a).

**Solution:**

Complete **GUIDE.md Module 2, Checkpoint 2a** first. The tools list requires a valid authenticated callout to the MCP server, which requires the principal with client_id/client_secret.

---

## Issue: Agent returns "no data" in Conversation Preview

**Symptom:** Agent activates successfully, but Conversation Preview returns "no data" or empty responses when asking about policies.

**Root causes (check in order):**

1. **MCP actions not wired to topics** — Module 4, Step 2 was skipped or incomplete.
2. **Platform Integration User (PIU) grant missing** — Module 2 PIU grant was skipped.
3. **Published before wiring actions** — see next issue.

**Solutions:**

1. Verify action wiring (UI track):
   - Setup → Agentforce → Agents → open Policy Agent
   - Check each topic has the correct MCP actions assigned
   - Re-add if missing

2. Verify PIU grant:
   ```bash
   sf apex run --file scripts/apex/assign-piu-permset.apex --target-org <alias>
   ```
   Look for `PIU_RESULT=✔` or `ℹ already assigned`.

3. If actions were wired AFTER publishing, they were wiped — see next issue.

---

## Issue: Published after wiring actions — "no data" regression

**Symptom:** MCP actions were wired in Agent Builder, agent worked in preview, then `sf agent publish` was run from source, and now the agent returns "no data."

**Root cause:** `sf agent publish authoring-bundle` **reverts in-org MCP tool bindings every time.** If you wire actions first and then publish, the bindings are wiped.

**Solution:**

**Always: publish → wire/re-wire actions → activate.**

1. Re-publish (to reset):
   ```bash
   sf agent publish authoring-bundle --api-name PolicyAgent --target-org <alias>
   ```

2. Re-wire all 3 MCP actions in Agent Builder (GUIDE.md Module 4, Step 2).

3. Re-activate:
   ```bash
   sf agent activate --api-name PolicyAgent --target-org <alias>
   ```

---

## Issue: Agent validation errors on .agent file

**Symptom:** `sf agent validate authoring-bundle` fails with syntax errors.

**Common causes:**

- Lowercase `true`/`false` instead of capitalized `True`/`False` in Agent Script (YAML-style booleans)
- Missing required blocks: `system`, `config`, `start_agent`
- Incorrect indentation (Agent Script is indentation-sensitive like Python/YAML)
- Missing `inputs` or `outputs` on an action

**Solution:**

Read the validation error carefully. Common fixes:

- Change `true` → `True`, `false` → `False`
- Ensure all subagent and action blocks are properly indented (4 spaces per level)
- Verify all actions have both `inputs` and `outputs` blocks
- For MCP actions, verify the `target` field uses the correct MCP tool URI format: `mcpTool://mcptoolx5fx5f<toolname>`

---

## Issue: Preview session fails with "tool not found"

**Symptom:** `sf agent preview send` returns "tool not found" or "action unavailable."

**Root causes:**

1. **MCP tools not registered** — Module 3 was skipped.
2. **`--use-live-actions` flag missing** — preview defaults to mock actions unless this flag is passed.

**Solutions:**

1. Register all 3 MCP tools (GUIDE.md Module 3).

2. Always use `--use-live-actions`:
   ```bash
   sf agent preview start --use-live-actions --authoring-bundle PolicyAgent --target-org <alias>
   ```

---

## Issue: OAuth token endpoint returns 400 or 401

**Symptom:** The MCP server's `/oauth/token` endpoint returns 400 or 401 during credential setup or smoke test.

**Root causes:**

1. **Invalid client_id or client_secret** — the credentials provided by the facilitator are wrong or expired.
2. **Scope mismatch** — the request must include `scope=read`.
3. **Grant type missing** — the request must include `grant_type=client_credentials`.

**Solutions:**

1. Verify the client_id/client_secret with your facilitator.

2. Confirm the External Credential's OAuth URL matches the workshop server:
   ```bash
   sf data query --query "SELECT OauthUrl FROM ExternalCredential WHERE DeveloperName = 'RiskonnectPolicyAdvisor'" -o <org>
   ```

3. Re-save the Named Principal with correct credentials (GUIDE.md Module 2, Checkpoint 2a).

---

## Issue: "Remote Site Settings" error on first callout

**Symptom:** First MCP callout returns "Unauthorized endpoint" or Remote Site Settings error.

**Root cause:** The Named Credential's endpoint is not in the org's Remote Site Settings.

**Solution:**

Re-save the Named Credential to trigger automatic Remote Site Setting creation:

1. Setup → Named Credentials → open `RiskonnectPolicyAdvisor`
2. Change nothing, just click **Save**
3. Retry the smoke test

---

## Issue: MCP Workbench package install fails

**Symptom:** The MCP Workbench unmanaged package fails to install.

**Root cause:** Package dependencies or org edition mismatch.

**Solution:**

MCP Workbench is **optional** — it is a diagnostic tool, not required for the workshop. If it fails to install:

1. Skip it and proceed with Module 2 verification via the smoke test script.
2. If troubleshooting is needed, use the `/diagnose-connection` skill in Claude Code instead (it does not require Workbench).

---

## Issue: Policy or gap records not appearing after seed script

**Symptom:** `./scripts/05-seed-data.sh` runs without errors, but Policy_Document__c or Policy_Gap__c records are not visible.

**Root causes:**

1. **Wrong org** — the script ran against a different org than expected.
2. **Permission set not assigned** — the user cannot see the custom objects.

**Solutions:**

1. Verify the correct org:
   ```bash
   sf org display --target-org <alias>
   ```

2. Assign the permission set:
   ```bash
   ./scripts/03-assign-perms.sh --org <alias>
   ```

3. Query the records:
   ```bash
   sf data query --query "SELECT Id, Name, Policy_ID__c FROM Policy_Document__c" -o <alias>
   sf data query --query "SELECT Id, Name, Severity__c FROM Policy_Gap__c" -o <alias>
   ```

---

## Issue: Clean metadata dry-run, but `sf agent publish` fails (validate is compile-only)

**Symptom:** `sf project deploy start --dry-run` reports 0 failures, but the agent later fails to
compile or returns no data — the dry-run gave false confidence.

**Root cause:** Metadata dry-run validates XML structure only; it never invokes the Agent Script
compiler. Two separate checks are needed:

- `sf agent validate authoring-bundle --api-name PolicyAgent` — runs the **Agent Script compiler**
  (catches indentation, `True`/`False`, block structure, unresolved `@actions.*` references).
- `sf agent publish authoring-bundle` — the **only** step that validates `mcpTool://` targets against
  actually-registered MCP assets, `default_agent_user`, and backing logic.

**Two things `validate` passing does NOT prove** (both surface only at publish/runtime):

1. **`source:` on an action is optional to the compiler.** The compiler accepts an action definition
   with or without a `source:` property (both return `success:true`). Whether `source:` is load-bearing
   for runtime MCP asset binding is unverified — we removed it because it is not a documented action
   property. If a published agent activates but returns no data, re-check the `mcpTool://` target and
   the in-org action wiring (Module 4, Step 2) before suspecting `source:`.
2. **The `mcpTool://` target string is not checked until publish.** Format is
   `mcpTool://mcptoolx5fx5f<toolname>` (`x5fx5f` encodes the `__` in the registered asset name). A wrong
   target publishes cleanly but silently returns no data.

**Structure rule (caused a real compile failure):** action **definitions** must live inside each owning
subagent's `actions:` block (sibling of `reasoning:`) — a single top-level `actions:` block is illegal
and fails with `Unknown block: actions`. The subagent's `reasoning.actions` only holds **invocations**
(`@actions.<name>`).

**`default_agent_user`:** an `AgentforceEmployeeAgent` must **omit** it (setting it causes publish to
fail with "Internal Error"). Only `AgentforceServiceAgent` requires it. A hook/lint warning about a
missing `default_agent_user` on an employee agent is a false positive — do not add it.

**Facilitator action:** run the full **Module 3 → publish → `sf agent preview --use-live-actions`** path
in a test org before the event. This is the only step that de-risks the `mcpTool://` binding end to end;
a clean `validate` is necessary but not sufficient.

---

## Issue: `sf agent mcp create --auth-type OAUTH` fails "Failed to fetch MCP server definition" (Track A)

**Symptom:** `sf agent mcp create ... --auth-type OAUTH --identity-provider <name>` returns
`BAD_REQUEST: API Catalog Error fetching server definition <name>: Failed to fetch MCP server
definition.` Nothing registers (`sf agent mcp list` stays empty).

**Verified root cause (2026-07-24, CLI 2.144.6, scratch org):** `--identity-provider` expects a
**classic `AuthProvider`** DeveloperName. Passing an `ExternalAuthIdentityProvider` (the construct the
repo deploys in Module 2, e.g. `RiskonnectPolicyAdvisorIdp`) does not resolve, and a fresh org has
**zero** classic AuthProviders. The command fails **before any HTTP callout** — confirmed by
`wrangler tail` on the mock server showing **zero requests** during an OAuTH `create`, while a
`--auth-type NO_AUTH` `create` against the same URL **did** hit the server (`POST /policy-advisor`).
So the OAuth identity-provider resolution is the blocker, not the URL, path, or credentials.

**How this was proven (reusable diagnostic):**
1. Confirm the creds/endpoint independently: `POST /oauth/token` returns 200 + `access_token`; an authed
   `POST /policy-advisor` `tools/list` returns the tools. (If this fails, it's a credential problem —
   see the `invalid_client` note below.)
2. `wrangler tail` the server, then run `create`. **Zero requests = failure is internal to Salesforce
   (pre-callout).** A control request (`curl .../health`) proves the tail is capturing.
3. Re-run with `--auth-type NO_AUTH` (drops `--identity-provider`). If a callout now appears, the OAuth
   identity-provider path is the culprit.

**`invalid_client` on `/oauth/token`:** the mock server checks **both** `client_id` and `client_secret`
and returns `invalid_client` (401) if **either** mismatches. Cloudflare secrets can't be read back — if
the pair is wrong, reset with `wrangler secret put CLIENT_ID` / `CLIENT_SECRET` (use a hex secret; avoid
`+ / =` which break form-encoding). Resetting `CLIENT_SECRET` invalidates all previously-issued bearer
tokens (they're stateless HMACs signed with it).

**Fix / recommendation:** **use Track B (UI)** for MCP registration — it reuses the Module 2
Named/External Credential, needs no AuthProvider, and is the guaranteed path. If you must use Track A
OAuth, hand-create a classic Auth Provider (Setup → Security → Auth. Providers) for the
client-credentials flow first, then pass its DeveloperName.

**Two more Track A gotchas (verified same session):**
- `--name` builds its own API Catalog named credential; using `RiskonnectPolicyAdvisor` **collides** with
  the Module 2 NamedCredential ("already exists"). Use a distinct name (e.g. `RiskonnectPolicyAdvisorMCP`).
- `--server-url` must include the `/policy-advisor` path; the base URL returns 404.

---

## Best Practices for Facilitators

1. **Pre-provision orgs** — Agentforce must be enabled by Salesforce support; participants cannot enable it themselves.

2. **Distribute credentials securely** — Use a temporary client_id/client_secret that expires after the workshop. Do not commit credentials to the repo.

3. **Test the happy path** — Run through the full workshop in a test org before the event to catch deployment/configuration issues.

4. **Monitor the MCP server** — If all participants hit the server simultaneously, rate limiting may trigger. Consider increasing limits or staggering Module 2 starts.

5. **Checkpoint enforcement** — The 🔴 checkpoints in GUIDE.md are the steps that silently break a build if rushed. Walk through each one explicitly before participants proceed.

6. **CLI vs UI preference survey** — Ask participants at the start which track they prefer (CLI or UI). Most will pick one and stick with it; a few will try both.

---

## Advanced Troubleshooting: Enable Debug Logs

If an MCP callout is failing silently:

1. Enable debug logs for your user:
   ```bash
   sf apex log tail --target-org <alias>
   ```

2. In another terminal, run the smoke test or trigger the agent:
   ```bash
   ./scripts/04-smoke-test.sh --org <alias>
   ```

3. Look for `CALLOUT_REQUEST` and `CALLOUT_RESPONSE` in the log to see the raw HTTP traffic.

---

## Getting Help

- **During the workshop:** Ask your facilitator or use the `/diagnose-connection` skill in Claude Code.
- **Post-workshop:** File an issue in the workshop repo with:
  - The exact error message or symptom
  - Which module/checkpoint you were on
  - Output of `sf org display --target-org <alias>` (redact sensitive info)
  - Output of the smoke test script
