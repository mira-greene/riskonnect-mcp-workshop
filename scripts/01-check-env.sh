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

# Check sf CLI version
if command -v sf &> /dev/null; then
  SF_VERSION=$(sf version --json | grep -o '"version":"[^"]*' | cut -d'"' -f4)
  info "Salesforce CLI version: $SF_VERSION"
fi

echo ""

# Check org authentication
check_org_auth "$ORG" || PREREQS_MET=false

echo ""

if [ "$PREREQS_MET" = true ]; then
  success "All prerequisites met!"
  echo ""
  info "Next step: Run ./scripts/02-deploy.sh --org $ORG"
  exit 0
else
  error "Some prerequisites are missing. Please install them and try again."
  exit 1
fi
