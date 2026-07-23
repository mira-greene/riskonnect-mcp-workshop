#!/bin/bash
# Assign permission set to the running user

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

echo "Assigning permission set to user..."
echo ""

# Parse org from args
ORG_ARG=$(parse_org_arg "$@")
ORG=$(get_org_alias "$ORG_ARG")

info "Target org: $ORG"
echo ""

# Get current username
USERNAME=$(sf org display --target-org "$ORG" --json | jq -r '.result.username // empty')
info "Current user: $USERNAME"
echo ""

# Assign permission set
PERMSET_NAME="Riskonnect_Policy_Agent_Perm_Set"

info "Assigning $PERMSET_NAME..."
# Run once and capture output. `set -e` is active, so guard the exit code with `|| true`.
ASSIGN_OUT=$(sf org assign permset --name "$PERMSET_NAME" --target-org "$ORG" 2>&1 || true)
if echo "$ASSIGN_OUT" | grep -qiE "already assigned|Duplicate PermissionSetAssignment"; then
  warning "Permission set already assigned (skipping)"
elif echo "$ASSIGN_OUT" | grep -qi "Assigned permission set\|Permission Set Assignment"; then
  success "Permission set assigned"
else
  error "Failed to assign permission set"
  echo "$ASSIGN_OUT"
  exit 1
fi

echo ""
info "Next step: Follow GUIDE.md Module 2 to configure the MCP credential"
