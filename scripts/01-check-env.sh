#!/bin/bash
# Check environment prerequisites for the workshop

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

echo "Checking environment prerequisites..."
echo ""

# Parse org from args
ORG_ARG=$(parse_org_arg "$@")
ORG=$(get_org_alias "$ORG_ARG")

# Check required commands
PREREQS_MET=true

check_command "sf" "Salesforce CLI" || PREREQS_MET=false
check_command "git" "Git" || PREREQS_MET=false

echo ""

# Check sf CLI version.
# Newer CLIs report {"cliVersion":"@salesforce/cli/2.x.y","version":null};
# older ones used {"version":"2.x.y"}. Parse either, and never let a failed
# match abort the script under `set -o pipefail`.
if command -v sf &> /dev/null; then
  SF_VERSION_JSON=$(sf version --json 2>/dev/null || echo "")
  SF_VERSION=$(printf '%s' "$SF_VERSION_JSON" | grep -o '@salesforce/cli/[0-9][0-9.]*' | head -1 | grep -o '[0-9][0-9.]*' || true)
  if [ -z "$SF_VERSION" ]; then
    SF_VERSION=$(printf '%s' "$SF_VERSION_JSON" | grep -o '"version": *"[0-9][0-9.]*"' | head -1 | grep -o '[0-9][0-9.]*' || true)
  fi
  info "Salesforce CLI version: ${SF_VERSION:-unknown}"
fi

echo ""

# Check org authentication
check_org_auth "$ORG" || PREREQS_MET=false

echo ""

# ---------------------------------------------------------------------------
# Org readiness probes (advisory — warnings only, never block).
# These surface the silent blockers that a plain auth check misses. A failed
# probe does NOT fail the script; it tells you what to fix before a module.
# Only run them if the org authenticated above.
# ---------------------------------------------------------------------------
if [ "$PREREQS_MET" = true ]; then
  info "Checking org readiness (advisory)..."

  # Agentforce enabled? (BotDefinition is queryable when Agentforce is on)
  if sf data query --query "SELECT Id FROM BotDefinition LIMIT 1" --target-org "$ORG" &> /dev/null; then
    success "Agentforce appears enabled (BotDefinition queryable)"
  else
    warning "Could not confirm Agentforce is enabled (BotDefinition not queryable). Needed for Modules 4-5; enablement is a Salesforce support request."
  fi

  # Platform Integration User present? (agent runtime callout runs as PIU — Module 2)
  PIU_COUNT=$(sf data query --query "SELECT COUNT() FROM User WHERE Name = 'Platform Integration User'" --target-org "$ORG" --json 2>/dev/null | grep -o '"totalSize": *[0-9][0-9]*' | head -1 | grep -o '[0-9][0-9]*' || echo "")
  if [ -n "${PIU_COUNT:-}" ] && [ "${PIU_COUNT}" != "0" ]; then
    success "Platform Integration User found (needed for the Module 2 callout)"
  else
    warning "Platform Integration User not found or not queryable. The Module 2 PIU grant (scripts/apex/assign-piu-permset.apex) may fail."
  fi

  # CLI track (Track A) available? `sf agent mcp` is Developer Preview.
  if sf agent mcp --help &> /dev/null; then
    success "CLI 'sf agent mcp' available (Module 3 Track A supported)"

    # Track A also needs an identity provider for OAuth. Report what exists.
    AP_COUNT=$(sf data query --query "SELECT COUNT() FROM AuthProvider" --target-org "$ORG" --json 2>/dev/null | grep -o '"totalSize": *[0-9][0-9]*' | head -1 | grep -o '[0-9][0-9]*' || echo "")
    if [ -n "${AP_COUNT:-}" ] && [ "${AP_COUNT}" != "0" ]; then
      success "$AP_COUNT Auth Provider(s) found (Track A --identity-provider prerequisite)"
    else
      warning "No Auth Providers found. Module 3 Track A (CLI) needs one; if you can't create it, use Track B (UI)."
    fi
  else
    warning "'sf agent mcp' not available in this CLI/org. Use Module 3 Track B (UI), or update: npm install -g @salesforce/cli@latest"
  fi

  echo ""
fi

if [ "$PREREQS_MET" = true ]; then
  success "All prerequisites met!"
  echo ""
  info "Next step: Run ./scripts/02-deploy.sh --org $ORG"
  exit 0
else
  error "Some prerequisites are missing. Please install them and try again."
  exit 1
fi
