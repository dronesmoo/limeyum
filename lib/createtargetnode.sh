#!/bin/bash
PROJECT_DIR="$1"
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
source "${PROJECT_DIR}/project.conf"

shopt -s xpg_echo
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "${BLUE}Adding new target to project${NC}"
read -p "Target URL: " TARGETURL
read -p "Target IP: " TARGETIP
read -p "Domain controler: " DC
read -p "How was target discovered: " DISCOVERED
mkdir -p "${PROJECT_DIR}/targets/${TARGETURL}_${TARGETIP}"
rc=$?
if [[ $rc -ne 0 ]]; then
    echo "[!] mkdir failed for ${PROJECT_DIR}/targets/${TARGETURL}_${TARGETIP} (exit code $rc)"
    exit 1
fi
echo "${GREEN}[+] Creating target directories"
TARGET_DIR="${PROJECT_DIR}/targets/${TARGETURL}_${TARGETIP}"
mkdir -p "${TARGET_DIR}/attacks"
rc=$?
if [[ $rc -ne 0 ]]; then
    echo "[!] mkdir failed for ${PROJECT_DIR}/targets/${TARGETURL}_${TARGETIP} (exit code $rc)"
    exit 1
fi
bash -c "ls ${PROJECT_DIR}"
echo "${GREEN}[+] Creating target configuration"
touch "${TARGET_DIR}/target.conf"
rc=$?
if [[ $rc -ne 0 ]]; then
    echo "[!] touch failed for target.conf (exit code $rc)"
    exit 1
fi
bash -c "ls ${TARGET_URL}"
cat >> "${TARGET_DIR}/target.conf" << EOF
Projectname="$PROJNAME"
TARGETIP="$TARGETIP"
TARGETURL="$TARGETURL"
Discovered="$(date '+%Y-%m-%d %H:%M')"
DiscoveredBy="$DISCOVERED"
TARGETDIR= "${PROJECT_DIR}/targets/${TARGETURL}_${TARGETIP}"
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
echo "${GREEN}[+] Created target${NC}"