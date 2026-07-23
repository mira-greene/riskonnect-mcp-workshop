#!/bin/bash
# Deploy all metadata to the org

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

echo "Deploying Riskonnect Policy Agent metadata..."
echo ""

# Parse org from args
ORG_ARG=$(parse_org_arg "$@")
ORG=$(get_org_alias "$ORG_ARG")

info "Target org: $ORG"
echo ""

# Deploy all metadata
info "Deploying force-app/main/default..."
if sf_run "project deploy start --source-dir force-app/main/default --target-org $ORG --wait 10"; then
  success "Deployment complete"
else
  error "Deployment failed"
  echo ""
  warning "If you see 'DeveloperName already in use', see GUIDE.md Module 1 troubleshooting"
  exit 1
fi

echo ""
info "Next step: Run ./scripts/03-assign-perms.sh --org $ORG"
