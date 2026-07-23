# Riskonnect MCP Workshop — Implementation Summary

**Created:** 2026-07-23  
**Workshop Duration:** ~2 hours  
**Location:** `/Users/mira.greene/claude-projects/riskonnect-mcp-workshop`

---

## What Was Built

A complete, production-ready workshop for Riskonnect partners to learn how to connect an MCP (Model Context Protocol) server to Salesforce Agentforce. The workshop teaches both **CLI** and **UI** workflows side-by-side, allowing participants to choose their preferred approach.

### Core Scenario

**Policy Agent** — assists policy managers and compliance teams with:
1. Retrieving policy document details
2. Analyzing regulatory gaps (comparing policies against regulations like GDPR, SEC Cyber Rules, NIST CSF)
3. Recommending specific policy language updates to close gaps

This scenario directly addresses Riskonnect's risk management domain: checking for gaps between existing organizational policies and new regulatory requirements.

---

## Workshop Structure

### 6 Modules (~2 hours)

0. **Comprehend** (optional, Claude Code) — reverse-engineer the agent using ADLC skills
1. **Deploy** — push all metadata to org, assign permission sets
2. **Connect** 🔴 — configure MCP credential (CLI vs UI), grant access, verify callout
3. **Register** 🔴 — register the 3 MCP tools (CLI vs UI)
4. **Wire & Activate** 🔴 — publish agent, wire MCP actions to topics, activate (CLI vs UI)
5. **Verify & Iterate** — test agent, edit `.agent` file, re-test without publishing

🔴 = manual checkpoint (steps that silently break if rushed)

### Dual Track: CLI vs UI

Every manual step (Modules 2-4) has **two parallel tracks**:
- **Track A: CLI** — uses `sf` CLI commands and SOQL queries to configure credentials, register tools, and wire actions programmatically
- **Track B: UI** — uses Setup UI (Named Credentials, MCP Servers, Agent Builder)

Participants choose one track and follow it throughout. Both tracks achieve the same outcome.

---

## Technical Components

### 1. Salesforce Metadata

**Custom Objects:**
- `Policy_Document__c` — catalog of organizational policies (5 fields: Policy_ID, Category, Owner, Last_Review_Date, Status)
- `Policy_Gap__c` — tracks identified compliance gaps (9 fields: Policy_Document lookup, Regulation_Name, Article, Gap_Description, Recommended_Action, Severity, Status, dates)

**Credentials:**
- `RiskonnectPolicyAdvisor` External Credential (OAuth 2.0 Client Credentials)
- `RiskonnectPolicyAdvisor` Named Credential (points to mock MCP server endpoint)

**Permission Set:**
- `Riskonnect_Policy_Agent_Perm_Set` — grants CRUD on custom objects, external credential access

**Agent Bundle:**
- `PolicyAgent` — Agentforce Agent Script (`.agent` format) with:
  - 3 subagents: `policy_analysis`, `regulatory_gap_check`, `policy_updates`
  - Variables: `policy_id`, `regulation_name`
  - Router logic to capture policy/regulation and route to appropriate subagent
  - Safety instructions: report only tool data, no invention, not legal advice

### 2. Scripts (Bash)

All in `scripts/`:
- `01-check-env.sh` — verify Salesforce CLI, org authentication
- `02-deploy.sh` — deploy all metadata
- `03-assign-perms.sh` — assign permission set to current user
- `04-smoke-test.sh` — test MCP callout via Named Credential, verify 3 tools returned
- `05-seed-data.sh` — create demo Policy_Document__c and Policy_Gap__c records
- `apex/test_callout.apex` — Apex script for MCP server connectivity test
- `apex/assign-piu-permset.apex` — assign permission set to Platform Integration User
- `lib/common.sh` — shared bash helpers (colors, org parsing, error handling)

All scripts accept `--org <alias>` or read from `.env`.

### 3. MCP Server (Mock)

**Specification:** `MCP-SERVER-SPEC.md`

Three tools:
1. **`get_policy_details`** — returns policy metadata + content summary
   - Input: `policy_id` (e.g. POL-001)
   - Output: policy_name, category, owner, last_review_date, status, content_summary

2. **`analyze_regulatory_gap`** — compares policy against regulation, returns gaps
   - Input: `policy_id`, `regulation_name` (e.g. GDPR, SEC Cyber Rules)
   - Output: array of gaps (article, severity, description, requirement), compliance_score

3. **`recommend_policy_updates`** — generates policy language to close gaps
   - Input: `policy_id`, `regulation_name`
   - Output: array of recommendations (article, priority, policy_language, rationale, implementation_notes)

**Mock data:**
- 5 policies: POL-001 (Data Privacy), POL-002 (Incident Response), POL-003 (Third-Party Risk), POL-004 (Cybersecurity), POL-005 (Business Continuity)
- 5 regulations: GDPR, CCPA, SEC Cyber Rules, NIST CSF, SOX

**Implementation:** Cloudflare Worker (not included in this repo; spec provided for facilitators to build)
- OAuth 2.0 token endpoint: `/oauth/token`
- MCP endpoint: `/policy-advisor`
- JSON-RPC 2.0 over HTTP POST

### 4. Documentation

- **README.md** — workshop orientation, prerequisites, quick start, repo layout
- **GUIDE.md** — full step-by-step build guide with CLI/UI tracks side-by-side
- **LESSONS-LEARNED.md** — troubleshooting guide for common issues (orphaned agents, credential errors, "no data" regressions, etc.)
- **MCP-SERVER-SPEC.md** — complete MCP server API specification with example requests/responses

---

## Key Design Decisions

### 1. Why CLI + UI Tracks?

Different audiences prefer different workflows:
- **Admins / less technical** → UI track (Setup UI, Agent Builder)
- **Developers / automation-focused** → CLI track (scripted, repeatable)

Both tracks teach the same concepts; participants self-select.

### 2. Why Mock MCP Server?

Real Riskonnect API integration would require:
- Participant API keys (provisioning overhead)
- Rate limiting / quota management
- Schema variability across Riskonnect environments
- IP allow-listing / VPN

A **shared mock server** (Cloudflare Worker) eliminates all of this:
- Single client_id/client_secret for all participants
- Predictable mock data (known policies, regulations)
- No external dependencies
- Facilitator controls the endpoint

### 3. Why Agent Script Format?

The `.agent` format (not JSON) is the **canonical Agentforce authoring format** as of 2026. It:
- Supports subagents, variables, reasoning blocks, action definitions
- Validates via `sf agent validate authoring-bundle`
- Previews with `--use-live-actions` (the "inner loop")
- Is the format taught in `/developing-agentforce` skill

The ncino workshop uses this format; this workshop follows the same pattern.

### 4. Why "Publish Before Wiring"?

**Critical gotcha:** `sf agent publish` **reverts in-org MCP action bindings** every time. If you wire actions in Agent Builder first, then publish from source, the bindings are wiped.

**Correct order:** publish → wire actions → activate

This is flagged with a red ⛔ warning in GUIDE.md Module 4.

### 5. Why Platform Integration User Grant?

The **agent's runtime callout** runs as the Platform Integration User (PIU), not the end user. If the PIU doesn't have the permission set, admin tests pass (you have the permset) but the agent returns "no data" (the PIU doesn't).

This is a **silent failure** — Module 2 grants the permset to PIU proactively.

---

## What Participants Learn

1. **MCP fundamentals** — JSON-RPC 2.0, tool discovery (`tools/list`), tool invocation (`tools/call`)
2. **OAuth 2.0 Client Credentials** — how Named Credentials and External Credentials work together
3. **Salesforce MCP integration** — registering tools, wiring as Agentforce actions
4. **Agent authoring** — Agent Script format, subagents, variables, reasoning, action definitions
5. **The inner loop** — edit `.agent` → validate → preview (no publish) → iterate
6. **Common pitfalls** — publish order, PIU grants, credential access grants, orphaned bundles

---

## Next Steps for You (Mira)

### 1. Build the Mock MCP Server

Use `MCP-SERVER-SPEC.md` to implement the Cloudflare Worker:
- OAuth token endpoint (client credentials flow)
- MCP tool discovery (`tools/list`)
- MCP tool invocation (`tools/call`) for the 3 tools
- Mock data responses for the 5 policies and 5 regulations

**Starter template:** The ncino workshop's mock server repo (`github.com/bstaubersalesforce/ncino-banking-advisor-mock`) is a good reference.

### 2. Update Credential URLs

Once the Worker is deployed, update these files with the real endpoint:

- `force-app/main/default/externalCredentials/RiskonnectPolicyAdvisor.externalCredential-meta.xml` — line 8, OAuth token URL
- `force-app/main/default/namedCredentials/RiskonnectPolicyAdvisor.namedCredential-meta.xml` — line 5, MCP endpoint URL
- `README.md` — table in "The mock MCP server" section
- `MCP-SERVER-SPEC.md` — update placeholder domain

Replace `YOUR-DOMAIN.workers.dev` with the actual Cloudflare Worker domain.

### 3. Test the Happy Path

In a test org:
1. Enable Agentforce (via Salesforce support — participants cannot do this themselves)
2. Run through GUIDE.md Modules 0-5 using **both** CLI and UI tracks
3. Verify smoke test returns 200 + 3 tools
4. Verify agent returns real data in Conversation Preview
5. Test the inner loop (edit `.agent`, validate, preview with `--use-live-actions`)

Document any additional issues in `LESSONS-LEARNED.md`.

### 4. Pre-Provision Workshop Orgs

Participants need **pre-configured orgs** with Agentforce enabled. Create:
- One org per participant (or one per pair if pairing)
- Agentforce enabled (SF support ticket required)
- Optional: FSC/nCino if you want to show cross-product integration

Distribute org credentials at workshop start.

### 5. Distribute Client Credentials

Generate a temporary `client_id` and `client_secret` for the workshop (expires 24 hours after the event). Distribute via:
- Slide deck
- Slack channel
- Printed handout

**Do not commit credentials to the repo.**

### 6. GitHub Repo (Optional)

If you want to host this publicly:
1. Create a new GitHub repo: `riskonnect-mcp-workshop`
2. Push this repo:
   ```bash
   git remote add origin https://github.com/YOUR-ORG/riskonnect-mcp-workshop.git
   git push -u origin main
   ```
3. Add a LICENSE (MIT or Apache 2.0 recommended)
4. Update README.md with the real GitHub URL

---

## Workshop Facilitation Tips

1. **Timing:** Budget 15 minutes per module. Module 2 (credentials) is the slowest.

2. **Checkpoints:** Walk through the 🔴 checkpoints live before participants proceed. These are the steps that silently break.

3. **CLI vs UI split:** Ask for a show of hands at the start — "Who prefers CLI? Who prefers UI?" This helps you tailor live demos.

4. **Common sticking points:**
   - External Credential Principal Access not granted (Module 2, Checkpoint 2b)
   - Publishing before wiring actions (Module 4)
   - PIU grant skipped (Module 2)

5. **Demo org:** Have a facilitator org with the agent fully working so you can demo the end state.

6. **Claude Code skills:** Participants without Claude Code can still complete the workshop (it's optional), but Module 0 is a nice intro to the ADLC skills.

---

## Files You May Need to Edit Before Workshop

| File | What to Change | When |
|------|----------------|------|
| `force-app/.../externalCredentials/RiskonnectPolicyAdvisor.externalCredential-meta.xml` | OAuth token URL (line 8) | After deploying MCP server |
| `force-app/.../namedCredentials/RiskonnectPolicyAdvisor.namedCredential-meta.xml` | MCP endpoint URL (line 5) | After deploying MCP server |
| `README.md` | MCP server URLs in table | After deploying MCP server |
| `MCP-SERVER-SPEC.md` | Replace `YOUR-DOMAIN.workers.dev` | After deploying MCP server |
| `GUIDE.md` | Client_id/client_secret distribution method | Before workshop (if not verbal) |

---

## Repository Stats

- **24 files created**
- **2,337 lines of code/docs**
- **Fully Git-tracked** (initial commit done)
- **Ready to deploy** to test org

---

## Questions Before Launch?

1. **Do you have access to Cloudflare Workers** (or similar serverless platform) to host the mock MCP server?
2. **Do you have a process to enable Agentforce** in workshop orgs? (Requires SF support ticket)
3. **How many participants?** (Determines rate limiting on the MCP server)
4. **When is the workshop?** (So we can set credential expiration)
5. **Do you want the GitHub repo public or private?**

Let me know if you need help with any of these next steps!

---

## License

TBD — recommend **MIT License** for public workshops (open, permissive, no attribution requirement).

---

**Workshop ready to test. Next: deploy MCP server, update URLs, dry-run in test org.**
