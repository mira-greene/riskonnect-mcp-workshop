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
USERNAME=$(sf org display --target-org "$ORG" --json | grep -o '"username":"[^"]*' | cut -d'"' -f4)
info "Current user: $USERNAME"
echo ""

# Assign permission set
PERMSET_NAME="Riskonnect_Policy_Agent_Perm_Set"

info "Assigning $PERMSET_NAME..."
if sf org assign permset --name "$PERMSET_NAME" --target-org "$ORG" 2>&1 | grep -q "already assigned"; then
  warning "Permission set already assigned"
elif sf_run "org assign permset --name $PERMSET_NAME --target-org $ORG"; then
  success "Permission set assigned"
else
  error "Failed to assign permission set"
  exit 1
fi

echo ""
info "Next step: Follow GUIDE.md Module 2 to configure the MCP credential"
