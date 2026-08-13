#!/bin/bash

TARGET_DIR="$1"

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[38;5;39m'
NC='\033[0m'

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
"

if [[ ! -f "$TARGET_DIR/target.conf" ]]; then
    echo -e "${RED}No target.conf found at $TARGET_DIR${NC}"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$TARGET_DIR/target.conf"
ATTACKMODULE="GoogleDork"

THISDIR="${TARGETDIR}/attacks/GoogleDork_${TIMESTAMP}"
HOMEPAGE="${THISDIR}/homepage.html"
CRAWLFILE="${THISDIR}/tempemails.txt

echo -e "${BLUE}Google Dorking $TARGETIP ($TARGETURL).${NC}"
read -p "Do you want to search for emails, passwords, and user names in found files (y/n)? " DEEPSEARCH
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"


mkdir -p "${THISDIR}"

echo "[+] Searching for PDF, DOC, and XLS files."
echo "$TIMESTAMP: Enumeration - $TARGETURL - Google Dork" >> "$PROJECTDIR/methodology.md"

URLFILE="${THISDIR}/GDFileList.txt"
touch "${URLFILE}"
cat >> "${URLFILE}" << 'EOF'
#Google Dork File Results
EOF

for FILETYPE in pdf xls xlsx doc
do
    echo -e "${BLUE}[+] Searching for ${FILETYPE} files.${NC}"
    QUERY="filetype:${FILETYPE}+site:${TARGETURL}"

    curl -s -A "$UA" \
        "https://www.google.com/search?q=${QUERY}&num=50" \
        -o "${THISDIR}/tempoutput_${FILETYPE}.html"

    grep -oP '(?<=/url\?q=)https?://[^&"]+' "${THISDIR}/tempoutput_${FILETYPE}.html" \
        | grep -i "\.${FILETYPE}" \
        | sort -u >> "${URLFILE}"

    COUNT=$(grep -ci "\.${FILETYPE}" "${THISDIR}/tempoutput_${FILETYPE}.html" 2>/dev/null || echo 0)
    echo -e "${GREEN}[+] Found matches for ${FILETYPE}${NC}"
    sleep 2
done


while IFS= read -r url; do
    [[ -z "$url" || "$url" == \#* ]] && continue
    fname=$(basename "${url%%\?*}")
    echo -e "${BLUE}    downloading: ${fname}${NC}"
    curl -sL -A "$UA" -o "${THISDIR}/${fname}" "$url"
    sleep 2   # be polite / avoid rate-limit block
done < "${URLFILE}"
echo "${BLUE}[+] Cleaning up files"
rm -f "${THISDIR}"/tempoutput*
echo "${BLUE}[+] Cleaned up files"
echo -e "[+] Searching for email addresses"
touch "${THISDIR}/emails.txt
echo -e "[+] Searching ${TARGETURL} for email addresses"
curl -sL -A "$UA" "https://${TARGETURL}" -o "${HOMEPAGE}"
echo -e "${GREEN}[+] Pulled homepage, extracting additional links"
LINKS=$(grep -oiP 'href="[^"]*"' "${HOMEPAGE}" \
    | sed -E 's/href="([^"]*)"/\1/' \
    | grep -iE 'contact|team|staff|about|people' \
    | sort -u)

if [[ -z "$LINKS" ]]; then
    echo -e "${YELLOW}[!] No contact/team/staff links found on homepage${NC}"
else
    echo -e "${GREEN}[+] Found $(echo "$LINKS" | wc -l) candidate page(s)${NC}."
fi
while IFS= read -r link; do
    [[ -z "$link" ]] && continue

    if [[ "$link" == http* ]]; then
        FULLURL="$link"
    else
        FULLURL="https://${TARGETURL%/}/${link#/}"
    fi

    printf "\r${BLUE}    fetching: %-80s${NC}" "${FULLURL:0:70}"
    curl -sL -A "$UA" "$FULLURL" >> "${CRAWLFILE}"
    sleep 1
done <<< "$LINKS"
echo 
echo -e "${GREEN}[+] Website data pulled successfully"
echo -e "${BLUE}[+] Gathering email addresses hosted on this site"
DOMAIN=$(echo "$TARGETURL" | sed -E 's|^https?://||; s|^www\.||; s|/.*$||')

grep -oiE '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' "${CRAWLFILE}" \
    | grep -iE "@([a-z0-9-]+\.)?${DOMAIN}$" \
    | sort -u >> "${THISDIR}/emails.txt"
echo -e "${GREEN}=== EMAIL SCAN COMPLETE ==="
echo "Results:"
cat ${THISDIR}/emails.txt
