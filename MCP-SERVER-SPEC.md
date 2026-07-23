# Riskonnect Policy Advisor MCP Server — Specification

This document describes the mock MCP server for the Riskonnect Policy Agent workshop. The server implements the Model Context Protocol (MCP) and provides three tools for policy gap analysis.

## Server Details

**Endpoint:** `https://riskonnect-policy-advisor.YOUR-DOMAIN.workers.dev/policy-advisor`  
**OAuth Token Endpoint:** `https://riskonnect-policy-advisor.YOUR-DOMAIN.workers.dev/oauth/token`  
**Protocol:** JSON-RPC 2.0 over HTTP POST  
**Authentication:** OAuth 2.0 Client Credentials

## OAuth 2.0 Client Credentials Flow

### Token Request

```http
POST /oauth/token
Content-Type: application/x-www-form-urlencoded

grant_type=client_credentials&client_id=<CLIENT_ID>&client_secret=<CLIENT_SECRET>&scope=read
```

### Token Response

```json
{
  "access_token": "<ACCESS_TOKEN>",
  "token_type": "Bearer",
  "expires_in": 3600,
  "scope": "read"
}
```

## MCP Tools

### 1. `get_policy_details`

Retrieve current policy document metadata and content summary.

**Method:** `tools/call`

**Request:**
```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "get_policy_details",
    "arguments": {
      "policy_id": "POL-001"
    }
  },
  "id": 1
}
```

**Response:**
```json
{
  "jsonrpc": "2.0",
  "result": {
    "content": [
      {
        "type": "text",
        "text": "{\"policy_id\":\"POL-001\",\"policy_name\":\"Data Privacy Policy\",\"category\":\"Data Privacy\",\"owner\":\"Jane Chen, Chief Privacy Officer\",\"last_review_date\":\"2024-03-15\",\"status\":\"Active\",\"content_summary\":\"Governs collection, use, storage, and disclosure of personal data. Covers data subject rights, consent management, data retention, and cross-border transfers. Currently aligned with CCPA; GDPR Article 30 ROPA requirements under review.\"}"
      }
    ]
  },
  "id": 1
}
```

**Input Schema:**
```json
{
  "type": "object",
  "properties": {
    "policy_id": {
      "type": "string",
      "description": "Policy identifier (e.g. POL-001)"
    }
  },
  "required": ["policy_id"]
}
```

**Output Schema:**
```json
{
  "type": "object",
  "properties": {
    "policy_id": {"type": "string"},
    "policy_name": {"type": "string"},
    "category": {"type": "string"},
    "owner": {"type": "string"},
    "last_review_date": {"type": "string"},
    "status": {"type": "string"},
    "content_summary": {"type": "string"}
  }
}
```

---

### 2. `analyze_regulatory_gap`

Compare a policy against a regulation to identify compliance gaps.

**Method:** `tools/call`

**Request:**
```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "analyze_regulatory_gap",
    "arguments": {
      "policy_id": "POL-001",
      "regulation_name": "GDPR"
    }
  },
  "id": 2
}
```

**Response:**
```json
{
  "jsonrpc": "2.0",
  "result": {
    "content": [
      {
        "type": "text",
        "text": "{\"policy_id\":\"POL-001\",\"policy_name\":\"Data Privacy Policy\",\"regulation_name\":\"GDPR\",\"gaps\":[{\"article\":\"Article 30\",\"severity\":\"High\",\"description\":\"Policy does not specify record of processing activities (ROPA) maintenance requirements. GDPR Article 30 mandates that controllers maintain records of all processing activities under their responsibility.\",\"requirement\":\"Controllers must maintain comprehensive records of processing activities including purposes, categories of data subjects and personal data, recipients, data retention periods, and security measures.\"},{\"article\":\"Article 35\",\"severity\":\"Medium\",\"description\":\"Policy lacks Data Protection Impact Assessment (DPIA) trigger criteria. GDPR Article 35 requires DPIAs for high-risk processing.\",\"requirement\":\"Organizations must conduct DPIAs when processing is likely to result in high risk to data subject rights and freedoms, particularly for new technologies, large-scale processing, or sensitive data.\"}],\"overall_compliance\":\"Partial\",\"compliance_score\":65}"
      }
    ]
  },
  "id": 2
}
```

**Input Schema:**
```json
{
  "type": "object",
  "properties": {
    "policy_id": {
      "type": "string",
      "description": "Policy identifier (e.g. POL-001)"
    },
    "regulation_name": {
      "type": "string",
      "description": "Regulation to analyze against (e.g. GDPR, CCPA, SEC Cyber Rules)"
    }
  },
  "required": ["policy_id", "regulation_name"]
}
```

**Output Schema:**
```json
{
  "type": "object",
  "properties": {
    "policy_id": {"type": "string"},
    "policy_name": {"type": "string"},
    "regulation_name": {"type": "string"},
    "gaps": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "article": {"type": "string"},
          "severity": {"type": "string"},
          "description": {"type": "string"},
          "requirement": {"type": "string"}
        }
      }
    },
    "overall_compliance": {"type": "string"},
    "compliance_score": {"type": "number"}
  }
}
```

---

### 3. `recommend_policy_updates`

Generate specific policy language recommendations to address regulatory gaps.

**Method:** `tools/call`

**Request:**
```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "recommend_policy_updates",
    "arguments": {
      "policy_id": "POL-001",
      "regulation_name": "GDPR"
    }
  },
  "id": 3
}
```

**Response:**
```json
{
  "jsonrpc": "2.0",
  "result": {
    "content": [
      {
        "type": "text",
        "text": "{\"policy_id\":\"POL-001\",\"policy_name\":\"Data Privacy Policy\",\"regulation_name\":\"GDPR\",\"recommendations\":[{\"article\":\"Article 30\",\"priority\":\"High\",\"policy_language\":\"The organization shall maintain a comprehensive record of all personal data processing activities under its responsibility. The record shall include: (a) the purposes of processing; (b) categories of data subjects and personal data; (c) categories of recipients to whom personal data has been or will be disclosed; (d) data retention periods; (e) description of technical and organizational security measures. Records shall be made available to the supervisory authority upon request.\",\"rationale\":\"GDPR Article 30 mandates that data controllers maintain records of processing activities. This language directly addresses the requirement and specifies the mandatory elements.\",\"implementation_notes\":\"Assign Data Privacy Officer to establish ROPA template and quarterly review process. Integrate with existing data inventory systems.\"},{\"article\":\"Article 35\",\"priority\":\"Medium\",\"policy_language\":\"A Data Protection Impact Assessment (DPIA) shall be conducted prior to implementing any processing activity that is likely to result in high risk to the rights and freedoms of data subjects, including: (a) systematic and extensive profiling with significant effects; (b) large-scale processing of special categories of data; (c) systematic monitoring of publicly accessible areas at large scale; (d) use of new technologies. The DPIA shall assess the necessity, proportionality, and measures to mitigate risks.\",\"rationale\":\"GDPR Article 35 requires DPIAs for high-risk processing. This language establishes clear trigger criteria and procedural requirements.\",\"implementation_notes\":\"Develop DPIA template and workflow. Train project managers on DPIA trigger assessment.\"}]}"
      }
    ]
  },
  "id": 3
}
```

**Input Schema:**
```json
{
  "type": "object",
  "properties": {
    "policy_id": {
      "type": "string",
      "description": "Policy identifier (e.g. POL-001)"
    },
    "regulation_name": {
      "type": "string",
      "description": "Regulation to address (e.g. GDPR, CCPA, SEC Cyber Rules)"
    }
  },
  "required": ["policy_id", "regulation_name"]
}
```

**Output Schema:**
```json
{
  "type": "object",
  "properties": {
    "policy_id": {"type": "string"},
    "policy_name": {"type": "string"},
    "regulation_name": {"type": "string"},
    "recommendations": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "article": {"type": "string"},
          "priority": {"type": "string"},
          "policy_language": {"type": "string"},
          "rationale": {"type": "string"},
          "implementation_notes": {"type": "string"}
        }
      }
    }
  }
}
```

---

## Tool Discovery

To list all available tools:

**Request:**
```json
{
  "jsonrpc": "2.0",
  "method": "tools/list",
  "params": {},
  "id": 1
}
```

**Response:**
```json
{
  "jsonrpc": "2.0",
  "result": {
    "tools": [
      {
        "name": "get_policy_details",
        "description": "Retrieve current policy document metadata and content summary",
        "inputSchema": { /* as above */ }
      },
      {
        "name": "analyze_regulatory_gap",
        "description": "Compare a policy against a regulation to identify compliance gaps",
        "inputSchema": { /* as above */ }
      },
      {
        "name": "recommend_policy_updates",
        "description": "Generate specific policy language recommendations to address regulatory gaps",
        "inputSchema": { /* as above */ }
      }
    ]
  },
  "id": 1
}
```

---

## Mock Data

The server returns mock data for the following policies:

- **POL-001**: Data Privacy Policy (Owner: Jane Chen)
- **POL-002**: Incident Response Policy (Owner: Mark Rodriguez)
- **POL-003**: Third-Party Risk Management Policy (Owner: Sarah Kim)
- **POL-004**: Cybersecurity Policy (Owner: Mark Rodriguez)
- **POL-005**: Business Continuity Policy (Owner: David Thompson)

Supported regulations for gap analysis:
- **GDPR** (EU General Data Protection Regulation)
- **CCPA** (California Consumer Privacy Act)
- **SEC Cyber Rules** (SEC Cybersecurity Disclosure Rules)
- **NIST CSF** (NIST Cybersecurity Framework)
- **SOX** (Sarbanes-Oxley Act)

---

## Implementation Notes for Workshop Facilitators

This MCP server should be implemented as a Cloudflare Worker (or similar serverless function) that:

1. Implements OAuth 2.0 client credentials flow with a shared client_id/client_secret
2. Validates Bearer tokens on incoming MCP requests
3. Returns the above JSON-RPC 2.0 responses for the three tools
4. Handles both `tools/list` (discovery) and `tools/call` (invocation)
5. Returns appropriate errors for invalid policy IDs or regulations

**Security:** The client_id and client_secret are distributed to workshop participants at the start. They are temporary credentials that expire after the workshop.

**Rate Limiting:** Consider implementing rate limiting (e.g., 100 requests/minute per client) to prevent abuse.

**Logging:** Log all tool invocations for workshop troubleshooting purposes.
