#!/bin/bash

RED=$'\033[0;31m'
YELLOW=$'\033[1;33m'
GREEN=$'\033[0;32m'
BLUE=$'\033[38;5;39m'
NC=$'\033[0m'

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
ATTACKMODULE="ExtEnum"

printf "${BLUE}Let's Enumerate!${NC}\n"

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
echo -e "$TIMESTAMP: Enumeration - $target - CRT.SH Scan" >> "/$TARGET_DIR/../methodology.md"

mkdir -p "${TARGET_DIR}/crtsh_${DOMAIN}_${TIMESTAMP}"
CRTSH_OUT="${TARGET_DIR}/crtsh_${DOMAIN}_${TIMESTAMP}/results.md"
touch "${CRTSH_OUT}"

printf "${BLUE}[+] Querying crt.sh for ${DOMAIN}...${NC}\n"

CRTSH_JSON=$(curl -s "https://crt.sh/?q=%25.${DOMAIN}&output=json")

if [[ -z "$CRTSH_JSON" || "$CRTSH_JSON" == "[]" ]]; then
    printf "${RED}[-] No crt.sh results for ${DOMAIN}${NC}\n"
else
    echo "# crt.sh Enumeration - ${DOMAIN}" > "$CRTSH_OUT"
    echo "" >> "$CRTSH_OUT"
    echo "_Queried: $(date)_" >> "$CRTSH_OUT"
    echo "" >> "$CRTSH_OUT"

    echo "$CRTSH_JSON" | jq -r '
        unique_by(.id) | sort_by(.not_after) | reverse | .[] |
        "### \(.name_value | split("\n")[0])\n" +
        "- **Common Name:** \(.common_name)\n" +
        "- **Issuer:** \(.issuer_name)\n" +
        "- **Not Before:** \(.not_before)\n" +
        "- **Not After (Expires):** \(.not_after)\n" +
        "- **Serial:** \(.serial_number)\n" +
        "- **crt.sh ID:** \(.id)\n"
    ' >> "$CRTSH_OUT"

    UNIQUE_SUBS=$(echo "$CRTSH_JSON" | jq -r '.[].name_value' | sed 's/\*\.//g' | sort -u | wc -l)

    printf "${GREEN}[+] crt.sh recon complete. ${UNIQUE_SUBS} unique subdomains found.${NC}\n"
    printf "${GREEN}[+] Saved to: ${CRTSH_OUT}${NC}\n"

    bash -c "cat ${CRTSH_OUT}"
fi