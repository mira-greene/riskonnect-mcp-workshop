// Riskonnect Policy Advisor — mock MCP server (Cloudflare Worker).
//
// Speaks:
//   POST /oauth/token    OAuth 2.0 Client Credentials -> Bearer access token
//   POST /policy-advisor JSON-RPC 2.0 MCP endpoint (initialize, tools/list, tools/call)
//   GET  /health         liveness probe (no auth)
//
// Secrets (CLIENT_ID, CLIENT_SECRET) come from Worker env / `wrangler secret` —
// NEVER hardcode them here or commit them. See README.md.

import {
  POLICIES,
  GAP_ANALYSIS,
  UPDATE_RECOMMENDATIONS,
  normalizeRegulation,
} from "./data.js";

const PROTOCOL_VERSION = "2024-11-05";
const TOKEN_TTL_SECONDS = 3600;

// Tool schemas advertised via tools/list.
const TOOLS = [
  {
    name: "get_policy_details",
    description:
      "Retrieve current policy document metadata and content summary by policy ID (e.g. POL-001).",
    inputSchema: {
      type: "object",
      properties: {
        policy_id: {
          type: "string",
          description: "The policy's POL-### identifier, e.g. POL-001.",
        },
      },
      required: ["policy_id"],
    },
  },
  {
    name: "analyze_regulatory_gap",
    description:
      "Compare a policy against a regulation to identify compliance gaps, each with a regulation article, severity, and requirement.",
    inputSchema: {
      type: "object",
      properties: {
        policy_id: { type: "string", description: "The policy's POL-### identifier." },
        regulation_name: {
          type: "string",
          description: "Regulation to analyze against, e.g. GDPR, CCPA, SEC Cyber Rules, NIST CSF, SOX.",
        },
      },
      required: ["policy_id", "regulation_name"],
    },
  },
  {
    name: "recommend_policy_updates",
    description:
      "Generate specific, ready-to-insert policy language recommendations that close the gaps between a policy and a regulation.",
    inputSchema: {
      type: "object",
      properties: {
        policy_id: { type: "string", description: "The policy's POL-### identifier." },
        regulation_name: {
          type: "string",
          description: "Regulation to address, e.g. GDPR, CCPA, SEC Cyber Rules, NIST CSF, SOX.",
        },
      },
      required: ["policy_id", "regulation_name"],
    },
  },
];

// ---- HTTP helpers -----------------------------------------------------------

function json(body, status = 200, extraHeaders = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json", ...extraHeaders },
  });
}

// JSON-RPC 2.0 result / error envelopes.
function rpcResult(id, result) {
  return json({ jsonrpc: "2.0", id, result });
}
function rpcError(id, code, message, httpStatus = 200) {
  return json({ jsonrpc: "2.0", id, error: { code, message } }, httpStatus);
}

// MCP tool results wrap a JSON payload as stringified text in content[0].
function toolContent(payload, isError = false) {
  return {
    content: [{ type: "text", text: JSON.stringify(payload, null, 2) }],
    isError,
  };
}

// ---- OAuth ------------------------------------------------------------------

// Opaque token = base64url(JSON{iat,exp,scope}).sig, HMAC-SHA256 over the body
// with CLIENT_SECRET. Stateless: no KV needed for a shared mock.
function b64urlEncode(bytes) {
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}
function b64urlDecodeToString(str) {
  const pad = str.length % 4 === 0 ? "" : "=".repeat(4 - (str.length % 4));
  const b64 = str.replace(/-/g, "+").replace(/_/g, "/") + pad;
  const bin = atob(b64);
  const bytes = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
  return new TextDecoder().decode(bytes);
}

async function hmac(secret, message) {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(message));
  return b64urlEncode(new Uint8Array(sig));
}

async function issueToken(env, nowSec, scope) {
  const body = b64urlEncode(
    new TextEncoder().encode(
      JSON.stringify({ iat: nowSec, exp: nowSec + TOKEN_TTL_SECONDS, scope })
    )
  );
  const sig = await hmac(env.CLIENT_SECRET, body);
  return `${body}.${sig}`;
}

// Constant-time-ish string compare (avoids trivial early-exit timing leak).
function safeEqual(a, b) {
  if (typeof a !== "string" || typeof b !== "string" || a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

async function verifyToken(env, token, nowSec) {
  if (!token || token.indexOf(".") === -1) return false;
  const [body, sig] = token.split(".");
  const expected = await hmac(env.CLIENT_SECRET, body);
  if (!safeEqual(sig, expected)) return false;
  try {
    const claims = JSON.parse(b64urlDecodeToString(body));
    return typeof claims.exp === "number" && claims.exp > nowSec;
  } catch {
    return false;
  }
}

// Accepts client creds from form body OR HTTP Basic auth header, per RFC 6749.
async function parseClientCredentials(request) {
  let clientId = null;
  let clientSecret = null;
  let grantType = null;
  let scope = "read";

  const auth = request.headers.get("authorization") || "";
  if (auth.toLowerCase().startsWith("basic ")) {
    try {
      const decoded = b64urlDecodeToString(
        auth.slice(6).replace(/\+/g, "-").replace(/\//g, "_")
      );
      const idx = decoded.indexOf(":");
      if (idx !== -1) {
        clientId = decoded.slice(0, idx);
        clientSecret = decoded.slice(idx + 1);
      }
    } catch {
      /* fall through to body parsing */
    }
  }

  const ct = (request.headers.get("content-type") || "").toLowerCase();
  if (ct.includes("application/x-www-form-urlencoded") || ct.includes("multipart/form-data")) {
    const form = await request.formData();
    grantType = form.get("grant_type");
    scope = form.get("scope") || scope;
    clientId = clientId || form.get("client_id");
    clientSecret = clientSecret || form.get("client_secret");
  } else if (ct.includes("application/json")) {
    const b = await request.json().catch(() => ({}));
    grantType = b.grant_type;
    scope = b.scope || scope;
    clientId = clientId || b.client_id;
    clientSecret = clientSecret || b.client_secret;
  }

  return { clientId, clientSecret, grantType, scope };
}

async function handleToken(request, env, nowSec) {
  const { clientId, clientSecret, grantType, scope } = await parseClientCredentials(request);

  if (grantType !== "client_credentials") {
    return json({ error: "unsupported_grant_type" }, 400);
  }
  if (!safeEqual(clientId || "", env.CLIENT_ID) || !safeEqual(clientSecret || "", env.CLIENT_SECRET)) {
    return json({ error: "invalid_client" }, 401);
  }

  const accessToken = await issueToken(env, nowSec, scope || "read");
  return json({
    access_token: accessToken,
    token_type: "Bearer",
    expires_in: TOKEN_TTL_SECONDS,
    scope: scope || "read",
  });
}

// ---- Tool dispatch ----------------------------------------------------------

function callTool(name, args) {
  const a = args || {};
  switch (name) {
    case "get_policy_details": {
      const policy = POLICIES[String(a.policy_id || "").trim().toUpperCase()];
      if (!policy) {
        return toolContent(
          { error: `Unknown policy_id "${a.policy_id}". Known policies: ${Object.keys(POLICIES).join(", ")}.` },
          true
        );
      }
      return toolContent(policy);
    }

    case "analyze_regulatory_gap": {
      const policyId = String(a.policy_id || "").trim().toUpperCase();
      if (!POLICIES[policyId]) {
        return toolContent(
          { error: `Unknown policy_id "${a.policy_id}". Known policies: ${Object.keys(POLICIES).join(", ")}.` },
          true
        );
      }
      const reg = normalizeRegulation(a.regulation_name);
      if (!reg) {
        return toolContent(
          { error: `Unknown regulation "${a.regulation_name}". Supported: GDPR, CCPA, SEC Cyber Rules, NIST CSF, SOX.` },
          true
        );
      }
      const analysis = GAP_ANALYSIS[`${policyId}|${reg}`];
      if (!analysis) {
        return toolContent({
          policy_id: policyId,
          policy_name: POLICIES[policyId].policy_name,
          regulation_name: reg,
          overall_compliance: "Compliant",
          compliance_score: 100,
          gaps: [],
          note: `No material gaps identified between ${policyId} and ${reg} in the advisory dataset.`,
        });
      }
      return toolContent({
        policy_id: policyId,
        policy_name: POLICIES[policyId].policy_name,
        regulation_name: reg,
        ...analysis,
      });
    }

    case "recommend_policy_updates": {
      const policyId = String(a.policy_id || "").trim().toUpperCase();
      if (!POLICIES[policyId]) {
        return toolContent(
          { error: `Unknown policy_id "${a.policy_id}". Known policies: ${Object.keys(POLICIES).join(", ")}.` },
          true
        );
      }
      const reg = normalizeRegulation(a.regulation_name);
      if (!reg) {
        return toolContent(
          { error: `Unknown regulation "${a.regulation_name}". Supported: GDPR, CCPA, SEC Cyber Rules, NIST CSF, SOX.` },
          true
        );
      }
      const recs = UPDATE_RECOMMENDATIONS[`${policyId}|${reg}`];
      if (!recs) {
        return toolContent({
          policy_id: policyId,
          policy_name: POLICIES[policyId].policy_name,
          regulation_name: reg,
          recommendations: [],
          note: `No update recommendations available for ${policyId} against ${reg}; run analyze_regulatory_gap first.`,
        });
      }
      return toolContent({
        policy_id: policyId,
        policy_name: POLICIES[policyId].policy_name,
        regulation_name: reg,
        recommendations: recs,
      });
    }

    default:
      return null; // signals "method not found" to the caller
  }
}

// ---- JSON-RPC / MCP ---------------------------------------------------------

async function handleRpc(request, env, nowSec) {
  // Auth: agent runtime sends the Named Credential's Bearer token.
  const auth = request.headers.get("authorization") || "";
  const token = auth.toLowerCase().startsWith("bearer ") ? auth.slice(7).trim() : null;
  if (!(await verifyToken(env, token, nowSec))) {
    return json(
      { jsonrpc: "2.0", id: null, error: { code: -32001, message: "Unauthorized: missing or invalid Bearer token." } },
      401,
      { "www-authenticate": "Bearer" }
    );
  }

  let msg;
  try {
    msg = await request.json();
  } catch {
    return rpcError(null, -32700, "Parse error", 400);
  }

  const { id, method, params } = msg || {};

  switch (method) {
    case "initialize":
      return rpcResult(id, {
        protocolVersion: PROTOCOL_VERSION,
        capabilities: { tools: { listChanged: false } },
        serverInfo: { name: "riskonnect-policy-advisor", version: "1.0.0" },
      });

    // Notifications carry no id and expect a 202 with no body.
    case "notifications/initialized":
    case "initialized":
      return new Response(null, { status: 202 });

    case "ping":
      return rpcResult(id, {});

    case "tools/list":
      return rpcResult(id, { tools: TOOLS });

    case "tools/call": {
      const toolName = params && params.name;
      const result = callTool(toolName, params && params.arguments);
      if (result === null) {
        return rpcError(id, -32602, `Unknown tool: ${toolName}`);
      }
      return rpcResult(id, result);
    }

    default:
      return rpcError(id, -32601, `Method not found: ${method}`);
  }
}

// ---- Entry point ------------------------------------------------------------

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    // nowSec is derived from the request; Date is available in the Worker runtime.
    const nowSec = Math.floor(Date.now() / 1000);

    if (url.pathname === "/health") {
      return json({ status: "ok", service: "riskonnect-policy-advisor" });
    }

    if (url.pathname === "/oauth/token") {
      if (request.method !== "POST") return json({ error: "method_not_allowed" }, 405);
      // Guard against missing configuration rather than issuing tokens signed with "undefined".
      if (!env.CLIENT_ID || !env.CLIENT_SECRET) {
        return json({ error: "server_misconfigured", error_description: "CLIENT_ID/CLIENT_SECRET not set" }, 500);
      }
      return handleToken(request, env, nowSec);
    }

    if (url.pathname === "/policy-advisor") {
      if (request.method !== "POST") return json({ error: "method_not_allowed" }, 405);
      if (!env.CLIENT_SECRET) {
        return json({ error: "server_misconfigured" }, 500);
      }
      return handleRpc(request, env, nowSec);
    }

    return json({ error: "not_found", path: url.pathname }, 404);
  },
};
