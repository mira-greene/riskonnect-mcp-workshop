#!/bin/bash
# Test MCP server connectivity via Named Credential

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

echo "Testing MCP server connectivity..."
echo ""

# Parse org from args
ORG_ARG=$(parse_org_arg "$@")
ORG=$(get_org_alias "$ORG_ARG")

info "Target org: $ORG"
echo ""

# Run the Apex test callout script
info "Executing test callout via Named Credential..."
RESULT=$(sf apex run --file "$SCRIPT_DIR/apex/test_callout.apex" --target-org "$ORG" 2>&1)

echo "$RESULT"
echo ""

# Check for success indicators
if echo "$RESULT" | grep -q "STATUS_CODE=200"; then
  success "MCP server connectivity confirmed"
  echo ""
  info "Expected: 3 tools listed (get_policy_details, analyze_regulatory_gap, recommend_policy_updates)"
  exit 0
else
  error "MCP server connectivity failed"
  echo ""
  warning "Common issues:"
  echo "  - 401/403: External Credential Principal Access not granted (GUIDE.md Module 2, Checkpoint 2b)"
  echo "  - 404: Named Credential URL mismatch"
  echo "  - Empty body: 'Generate Authorization Header' not enabled on Named Credential"
  echo ""
  info "For detailed diagnosis, run the /diagnose-connection skill in Claude Code"
  exit 1
fi
