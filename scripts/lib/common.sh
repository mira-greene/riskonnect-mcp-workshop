#!/bin/bash
# Common shell functions for workshop scripts

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Load .env if it exists
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
fi

# Get org alias from args or env
get_org_alias() {
  local org="${1:-}"
  if [ -z "$org" ]; then
    org="${ORG_ALIAS:-}"
  fi

  if [ -z "$org" ]; then
    echo -e "${RED}Error: No org alias provided.${NC}" >&2
    echo "Usage: $0 [--org <alias>] or set ORG_ALIAS in .env" >&2
    exit 1
  fi

  echo "$org"
}

# Parse --org flag from args
parse_org_arg() {
  local org=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --org|-o)
        org="$2"
        shift 2
        ;;
      *)
        shift
        ;;
    esac
  done
  echo "$org"
}

# Check if command exists
check_command() {
  local cmd="$1"
  local name="${2:-$1}"

  if ! command -v "$cmd" &> /dev/null; then
    echo -e "${RED}✗ $name not found${NC}"
    return 1
  else
    echo -e "${GREEN}✓ $name found${NC}"
    return 0
  fi
}

# Check if org is authenticated
check_org_auth() {
  local org="$1"

  if ! sf org display --target-org "$org" &> /dev/null; then
    echo -e "${RED}✗ Org '$org' not authenticated${NC}"
    echo -e "${YELLOW}Run: sf org login web --alias $org${NC}"
    return 1
  else
    echo -e "${GREEN}✓ Org '$org' authenticated${NC}"
    return 0
  fi
}

# Success message
success() {
  echo -e "${GREEN}✓ $1${NC}"
}

# Error message
error() {
  echo -e "${RED}✗ $1${NC}" >&2
}

# Warning message
warning() {
  echo -e "${YELLOW}⚠ $1${NC}"
}

# Info message
info() {
  echo -e "${BLUE}ℹ $1${NC}"
}

# Run sf command with error handling
sf_run() {
  local cmd="$*"

  if ! eval "sf $cmd"; then
    error "Command failed: sf $cmd"
    return 1
  fi
  return 0
}
