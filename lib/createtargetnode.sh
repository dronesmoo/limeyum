#!/bin/bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[38;5;39m'
NC='\033[0m'

die() {
    echo "${RED}[!] $1${NC}"
    exit 1
}

shopt -s xpg_echo

# --- Load project config ---
if [[ ! -f "${SCRIPT_DIR}/project.conf" ]]; then
    die "project.conf not found in ${SCRIPT_DIR}"
fi
source "${SCRIPT_DIR}/project.conf"

if [[ -z "${PROJNAME:-}" ]]; then
    die "PROJNAME is not set in project.conf"
fi

# --- Validate args ---
if [[ -z "${1:-}" ]]; then
    die "Usage: $0 <project_dir>"
fi
PROJECT_DIR="$1"

if [[ ! -d "$PROJECT_DIR" ]]; then
    die "Project directory does not exist: ${PROJECT_DIR}"
fi

if [[ ! -w "$PROJECT_DIR" ]]; then
    die "No write permission on project directory: ${PROJECT_DIR}"
fi

echo "${BLUE}Adding new target to project${NC}"

read -p "Target URL: " TARGETURL
read -p "Target IP: " TARGETIP
read -p "Domain controler: " DC
read -p "How was target discovered: " DISCOVERED

if [[ -z "$TARGETURL" || -z "$TARGETIP" ]]; then
    die "Target URL and Target IP cannot be empty"
fi

TARGET_DIR="${PROJECT_DIR}/targets/${TARGETURL}_${TARGETIP}"

if [[ -d "$TARGET_DIR" ]]; then
    die "Target already exists: ${TARGET_DIR}"
fi

# --- Create directories ---
if ! mkdir -p "${TARGET_DIR}/attacks"; then
    die "Failed to create target directory: ${TARGET_DIR}/attacks"
fi
echo "${GREEN}[+] Creating target directories${NC}"

if [[ ! -d "$TARGET_DIR" ]]; then
    die "Target directory does not exist after mkdir (unexpected): ${TARGET_DIR}"
fi

# --- Write target.conf ---
echo "${GREEN}[+] Creating target configuration${NC}"

cat > "${TARGET_DIR}/target.conf" << EOF
Projectname="$PROJNAME"
TARGETIP="$TARGETIP"
TARGETURL="$TARGETURL"
Discovered="$(date '+%Y-%m-%d %H:%M')"
DiscoveredBy="$DISCOVERED"
TARGETDIR="${TARGET_DIR}"
PROJECTDIR="${PROJECT_DIR}"
DOMAINCONTROLLER="${DC}"

#PORTS_START
#PORTS_END

#VULNS_START
#VULNS_END

#CREDS_START
#CREDS_END

#SESSION_START
#SESSION_END

#SERVICES_START
#SERVICES_END

#EMAILS_START
#EMAILS_END
EOF

if [[ $? -ne 0 ]]; then
    die "Failed to write target.conf"
fi

if [[ ! -s "${TARGET_DIR}/target.conf" ]]; then
    die "target.conf was created but is empty"
fi

echo "${GREEN}[+] Created target${NC}"
echo "${GREEN}[+] Location: ${TARGET_DIR}${NC}"