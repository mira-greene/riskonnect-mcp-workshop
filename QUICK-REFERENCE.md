# Quick Reference Card — Riskonnect MCP Workshop

Print this page or keep it open as a reference during the workshop.

---

## Workshop Flow (2 hours)

```
0. Comprehend (optional)  → Claude Code: reverse-engineer agent
1. Deploy               → scripts 01-03: push metadata, assign permset
2. Connect 🔴          → add MCP credential, grant access, smoke test
3. Register 🔴         → register 3 MCP tools
4. Wire & Activate 🔴  → publish → wire actions → activate
5. Verify & Iterate     → test agent, edit .agent, preview loop
```

🔴 = manual checkpoint (choose CLI or UI track)

---

## Essential Commands

### Environment Check & Deploy
```bash
./scripts/01-check-env.sh --org <alias>    # verify prerequisites
./scripts/02-deploy.sh --org <alias>       # deploy all metadata
./scripts/03-assign-perms.sh --org <alias> # assign permission set
./scripts/04-smoke-test.sh --org <alias>   # test MCP connectivity (expect 200 + 3 tools)
./scripts/05-seed-data.sh --org <alias>    # seed demo data (optional)
```

### Agent Commands
```bash
# List agent bundles
sf project list metadata --metadata-type AiAuthoringBundle --target-org <alias>

# Validate agent
sf agent validate authoring-bundle --api-name PolicyAgent --target-org <alias>

# Publish agent
sf agent publish authoring-bundle --api-name PolicyAgent --target-org <alias>

# Activate agent
sf agent activate --api-name PolicyAgent --target-org <alias>

# Preview with live actions (the inner loop)
sf agent preview start --use-live-actions --authoring-bundle PolicyAgent --target-org <alias>
# → capture the sessionId
sf agent preview send --authoring-bundle PolicyAgent --session-id <sessionId> \
  -u "Analyze our data privacy policy against GDPR" --target-org <alias>
```

---

## The 3 MCP Tools

| Tool | What it does | Example prompt |
|------|--------------|----------------|
| **`get_policy_details`** | Retrieve policy metadata + content summary | "Show me the current data privacy policy" |
| **`analyze_regulatory_gap`** | Compare policy vs regulation, return gaps | "Analyze our data privacy policy against GDPR Article 30" |
| **`recommend_policy_updates`** | Generate policy language to close gaps | "What updates should we make to our incident response policy for SEC cyber rules?" |

---

## Known Policies (Mock Data)

- **POL-001**: Data Privacy Policy (Owner: Jane Chen)
- **POL-002**: Incident Response Policy (Owner: Mark Rodriguez)
- **POL-003**: Third-Party Risk Management Policy (Owner: Sarah Kim)
- **POL-004**: Cybersecurity Policy (Owner: Mark Rodriguez)
- **POL-005**: Business Continuity Policy (Owner: David Thompson)

---

## Supported Regulations (Mock Data)

- **GDPR** (EU General Data Protection Regulation)
- **CCPA** (California Consumer Privacy Act)
- **SEC Cyber Rules** (SEC Cybersecurity Disclosure Rules)
- **NIST CSF** (NIST Cybersecurity Framework)
- **SOX** (Sarbanes-Oxley Act)

---

## Troubleshooting Quick Hits

| Symptom | Fix |
|---------|-----|
| Deploy fails "DeveloperName already in use" | `sf org list metadata -m AiAuthoringBundle` → find orphan → `sf project delete source --metadata "AiAuthoringBundle:<name>"` |
| Smoke test returns 401/403 | External Credential Principal Access not granted → redo Module 2, Checkpoint 2b |
| Smoke test returns 404 | Named Credential URL mismatch → check Setup → Named Credentials |
| MCP tools list is empty | Named Principal not created yet → complete Module 2, Checkpoint 2a first |
| Agent returns "no data" | (1) MCP actions not wired, (2) PIU grant missing, (3) published before wiring actions |
| "Tool not found" in preview | Add `--use-live-actions` flag to `sf agent preview start` |

**Full troubleshooting:** see `LESSONS-LEARNED.md`

---

## Critical Order (Module 4)

⛔ **ALWAYS:** publish → wire actions → activate  
❌ **NEVER:** wire actions → publish (this wipes the bindings)

```bash
# 1. Publish
sf agent publish authoring-bundle --api-name PolicyAgent --target-org <alias>

# 2. Wire actions in Agent Builder (or via CLI)
#    - Policy Analysis topic: get_policy_details, recommend_policy_updates
#    - Regulatory Gap Check topic: analyze_regulatory_gap

# 3. Activate
sf agent activate --api-name PolicyAgent --target-org <alias>
```

---

## The Inner Loop (No Publish Needed)

```bash
# 1. Edit the .agent file
vim force-app/main/default/aiAuthoringBundles/PolicyAgent/PolicyAgent.agent

# 2. Validate
sf agent validate authoring-bundle --api-name PolicyAgent --target-org <alias>

# 3. Preview with live actions
sf agent preview start --use-live-actions --authoring-bundle PolicyAgent --target-org <alias>
sf agent preview send --authoring-bundle PolicyAgent --session-id <sessionId> -u "..." --target-org <alias>

# 4. Iterate — repeat steps 1-3 until satisfied, THEN publish
```

---

## Claude Code Skills (Optional, Module 0)

Install these plugins:
```
/plugin marketplace add SalesforceAIResearch/agentforce-adlc
/plugin install agentforce-adlc@agentforce-adlc

/plugin marketplace add mvogelgesang/sf-mcp-partner-toolkit
/plugin install sf-mcp-partner-toolkit@mvogelgesang-plugins
```

Use these skills:
- `/developing-agentforce` — build, edit, validate, preview agent
- `/testing-agentforce` — write and run agent test specs
- `/diagnose-connection` — troubleshoot MCP connectivity
- `/validate-end-to-end` — confirm MCP integration works end-to-end

---

## Useful Queries

```bash
# List Named Credentials
sf data query --query "SELECT DeveloperName, Url FROM NamedCredential" --target-org <alias>

# List External Credentials
sf data query --query "SELECT DeveloperName FROM ExternalCredential" --target-org <alias>

# Check permission set assignments
sf data query --query "SELECT Assignee.Name, PermissionSet.Name FROM PermissionSetAssignment WHERE PermissionSet.Name = 'Riskonnect_Policy_Agent_Perm_Set'" --target-org <alias>

# List Policy Documents
sf data query --query "SELECT Id, Name, Policy_ID__c, Status__c FROM Policy_Document__c" --target-org <alias>

# List Policy Gaps
sf data query --query "SELECT Id, Name, Regulation_Name__c, Severity__c FROM Policy_Gap__c" --target-org <alias>
```

---

## MCP Server Details

**Endpoint:** `https://riskonnect-policy-advisor.YOUR-DOMAIN.workers.dev/policy-advisor`  
**Token URL:** `https://riskonnect-policy-advisor.YOUR-DOMAIN.workers.dev/oauth/token`  
**Auth:** OAuth 2.0 Client Credentials  
**Protocol:** JSON-RPC 2.0

---

## Custom Objects

- **Policy_Document__c**: Policy_ID (ext), Category, Owner, Last_Review_Date, Status
- **Policy_Gap__c**: Policy_Document (lookup), Regulation_Name, Article, Gap_Description, Recommended_Action, Severity, Status, dates

---

## Getting Help

- **GUIDE.md** — full step-by-step instructions
- **LESSONS-LEARNED.md** — troubleshooting common issues
- **Your facilitator** — during the workshop
- **GitHub Issues** — https://github.com/mira-greene/riskonnect-mcp-workshop/issues

---

**Happy building! 🚀**
