#!/bin/bash
# Seed demo Policy_Gap__c and Policy_Document__c records

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

echo "Seeding demo policy and gap data..."
echo ""

# Parse org from args
ORG_ARG=$(parse_org_arg "$@")
ORG=$(get_org_alias "$ORG_ARG")

info "Target org: $ORG"
echo ""

# Run the Apex seed script
info "Creating Policy_Document__c records..."
sf apex run --file "$SCRIPT_DIR/../data/seed-policies.apex" --target-org "$ORG"

echo ""
info "Creating Policy_Gap__c records..."
sf apex run --file "$SCRIPT_DIR/../data/seed-gaps.apex" --target-org "$ORG"

echo ""
success "Seed data created"
info "View records: sf org open --target-org $ORG → Policy Documents / Policy Gaps tabs"
