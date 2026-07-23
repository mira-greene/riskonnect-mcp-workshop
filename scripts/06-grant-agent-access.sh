#!/bin/bash
# Deploy and assign the agent-run access permission set.
# Run this in Module 4, AFTER the PolicyAgent bundle is published — the permission set
# references the published Bot, so it will not deploy before then.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

echo "Granting Policy Agent run access..."
echo ""

# Parse org from args
ORG_ARG=$(parse_org_arg "$@")
ORG=$(get_org_alias "$ORG_ARG")

info "Target org: $ORG"
echo ""

PERMSET_NAME="Riskonnect_Policy_Agent_Access"

info "Deploying $PERMSET_NAME (references the published PolicyAgent Bot)..."
if sf_run "project deploy start --source-dir agent-access/main/default --target-org $ORG --wait 10"; then
  success "Access permission set deployed"
else
  error "Deploy failed"
  echo ""
  warning "'no Bot named PolicyAgent found' means the agent isn't published yet — complete Module 4 Step 1 first."
  exit 1
fi

echo ""
info "Assigning $PERMSET_NAME..."
if sf org assign permset --name "$PERMSET_NAME" --target-org "$ORG" 2>&1 | grep -q "already assigned"; then
  warning "Permission set already assigned"
elif sf_run "org assign permset --name $PERMSET_NAME --target-org $ORG"; then
  success "Access permission set assigned"
else
  error "Failed to assign permission set"
  exit 1
fi

echo ""
info "Next step: Module 5 — open Agent Builder → Conversation Preview and test the agent."
