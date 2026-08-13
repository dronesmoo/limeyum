#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"

PROJECT_DIR="$1"

if [[ -z "$PROJECT_DIR" ]]; then
    echo "[!] Usage: $0 <project_dir>"
    exit 1
fi

if [[ ! -f "${PROJECT_DIR}/project.conf" ]]; then
    echo "[!] project.conf not found in ${PROJECT_DIR}"
    exit 1
fi
source "${PROJECT_DIR}/project.conf"

shopt -s xpg_echo
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[38;5;39m'
NC='\033[0m'

echo "${BLUE}Adding new target to project${NC}"
read -p "Target URL: " TARGETURL
read -p "Target IP: " TARGETIP
read -p "Domain controler: " DC
read -p "How was target discovered: " DISCOVERED

if [[ -z "$TARGETURL" || -z "$TARGETIP" ]]; then
    echo "[!] Target URL and Target IP cannot be empty"
    exit 1
fi

mkdir -p "${PROJECT_DIR}/targets/${TARGETURL}_${TARGETIP}"
if [[ ! -d "${PROJECT_DIR}/targets/${TARGETURL}_${TARGETIP}" ]]; then
    echo "[!] Failed to create target directory"
    exit 1
fi
echo "${GREEN}[+] Creating target directories"

cd "${PROJECT_DIR}/targets/${TARGETURL}_${TARGETIP}" || { echo "[!] Failed to cd into target directory"; exit 1; }
mkdir -p attacks
echo "${GREEN}[+] Creating target configuration"
touch target.conf
cat >> "${PROJECT_DIR}/targets/${TARGETURL}_${TARGETIP}/target.conf" << EOF
Projectname="$PROJNAME"
TARGETIP="$TARGETIP"
TARGETURL="$TARGETURL"
Discovered="$(date '+%Y-%m-%d %H:%M')"
DiscoveredBy="$DISCOVERED"
TARGETDIR="${PROJECT_DIR}/targets/${TARGETURL}_${TARGETIP}"
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
    echo "[!] Failed to write target.conf"
    exit 1
fi

echo "${GREEN}[+] Created target${NC}"