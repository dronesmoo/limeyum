#!/bin/bash

RED=$'\033[0;31m'
YELLOW=$'\033[1;33m'
GREEN=$'\033[0;32m'
BLUE=$'\033[38;5;39m'
NC=$'\033[0m'

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
ATTACKMODULE="dig"

printf "${BLUE}Let's DIG!${NC}\n"

TARGET_DIR="$1"
if [[ ! -f "$TARGET_DIR/target.conf" ]]; then
    echo "${RED}No target.conf found at $TARGET_DIR${NC}"
    read -p "Target IP: " TARGETIP
    read -p "Target URL: " TARGETURL

else
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$TARGET_DIR/target.conf"   # now $TARGETIP, $TARGETURL, etc. are set
fi

DOMAIN=$(echo "$TARGETURL" | sed -E 's|^https?://||; s|^www\.||; s|/.*$||')
printf "${GREEN}[+]Target set${NC}\n"
echo -e "$TIMESTAMP: Enumeration - $target - DNS Scan" >> "/$TARGET_DIR/../methodology.txt"

mkdir -p "${TARGET_DIR}/attacks/${TIMESTAMP}_dns"
OUTFILE="${TARGET_DIR}/{TIMESTAMP}_dns/results.md"
printf "${BLUE}[+] Starting A record scan${NC}"
bash -c "dig --short A ${TARGETURL} +noall +answer | tee ${OUTFILE}"
printf "${BLUE}[+] Starting CNA<E record scan${NC}"
bash -c "dig --short CNAME ${TARGETURL} +noall +answer | tee ${OUTFILE}"
printf "${BLUE}[+] Starting TXT record scan${NC}"
bash -c "dig --short TXT ${TARGETURL} +noall +answer | tee ${OUTFILE}"
printf "${BLUE}[+] Starting MX record scan${NC}"
bash -c "dig --short MX ${TARGETURL} +noall +answer | tee ${OUTFILE}"
print f "${GREEN}=== SCAN COMPLETE ==="
basch -c "cat ${OUTFILE}"
read -p "Do you want to add these as targets (y/n)? " ADDTARGETS

if [[ $ADDTARGETS = "y" ]]
    printf "Oops, you need to do it manually"
fi