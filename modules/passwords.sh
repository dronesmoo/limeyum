#!/bin/bash

TARGET_DIR="$1"
if [[ ! -f "$TARGET_DIR/target.conf" ]]; then
    echo "${RED}No target.conf found at $TARGET_DIR${NC}"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$TARGET_DIR/target.conf"   # now $TargetIP, $TargetURL, etc. are set
ATTACKMODULE=""


RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[38;5;39m'
NC='\033[0m'

echo "${BLUE}Password attacking $TARGETIP ($TARGETURL)."