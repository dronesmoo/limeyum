#!/bin/bash

RED=$'\033[0;31m'
YELLOW=$'\033[1;33m'
GREEN=$'\033[0;32m'
BLUE=$'\033[0;34m'
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
echo -e "$TIMESTAMP: Enumeration - $target - External Enumeration" >> "../$TARGET_DIR/methodology.md"

echo "This will mirror the site and search files for login fields, contact forms, emails, and passwords."
read -p "Continue (y/n)? " CONTINUE
read -p "Do you want to Google-Dork (y/n)? " GD
if [[ $CONTINUE != "y" ]]; then
exit 1
fi
THISDIR="${TARGET_DIR}/${TIMESTAMP}_sitepull"
mkdir "${THISDIR}"
printf "${BLUE}[+] Pulling website${NC}\n"
wget --mirror --convert-links --adjust-extension --page-requisites --no-parent "${TARGETURL}" -P "${THISDIR}/website"
printf "${GREEN}[+] Site pulled, now finding interesting data.${NC}\n"
printf "${BLUE}[+] Searching for email addresses${NC}\n"
touch "${THISDIR}/emails.txt
grep -oiE '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' "${THISDIR}/website" \
    | grep -iE "@([a-z0-9-]+\.)?${DOMAIN}$" \
    | sort -u >> "${THISDIR}/emails.txt"
echo -e "${GREEN}=== EMAIL SCAN COMPLETE ==="
printf "${BLUE}[+] Finding Password fields"
grep -oiE 'pass' "${THISDIR}/website >> "${THISDIR}/passwordfields.txt"
printf "${GREEN}=== PASSWORD SCAN COMPLETE ===\nEmails found:\n"
cat "${THISDIR}/emails.txt"
printf "Potential Passord Fields Found:\n"
cat "${THISDIR}/passwordfields.txt"


if [[ $GD == "y" ]]; then
    printf "${BLUE}[+] Starting Google Dork${NC}\n"
    bash -c "${SCRIPT_DIR}/google-dork.sh ${TARGET_DIR}"
fi