#!/bin/bash

RED=$'\033[0;31m'
YELLOW=$'\033[1;33m'
GREEN=$'\033[0;32m'
BLUE=$'\033[38;5;39m'
NC=$'\033[0m'

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
ATTACKMODULE="ExtEnum"

printf "${BLUE}Let's Enumerate!${NC}\n"

PROJECTDIR="$1"
CONF_FILE=$(find "$PROJECTDIR" -maxdepth 1 -name "*.conf" -print -quit)

if [[ -f "$CONF_FILE" ]]; then
    source "$CONF_FILE"
else
    echo "${RED}No .conf file found in $TARGET_DIR${NC}"
    exit 1
fi

print_vulns_table() {
    local conf_file="$1"
    local vulns
    vulns=$(extract_block "VULNS" "$conf_file")

    if [[ -n "$vulns" ]]; then
        echo "| Date | Vulnerability | Severity | Description |" >> "${REPORT}"
        echo "|------|---------------|----------|--------------|" >> "${REPORT}"
        while IFS='|' read -r date vuln severity desc; do
            [[ -n "$date" ]] || continue
            echo "| ${date} | ${vuln} | ${severity} | ${desc} |" >> "${REPORT}"
        done <<< "$vulns"
    else
        echo "_No vulnerabilities recorded._" >> "${REPORT}"
    fi
}

DOMAIN=$(echo "$TARGETURL" | sed -E 's|^https?://||; s|^www\.||; s|/.*$||')
printf "${GREEN}[+]Project set\n"
echo "[+] Creating base report"
REPORT="${PROJECTDIR}/report_${TIMESTAMP}.md"
touch "${REPORT}"
cat > "${REPORT}" << EOF
# ${Projectname}
**Evaluation Type:** ${Type}
**Initial IP:** ${TargetIP}
**Initial URL:** ${TargetURL}
**Started:** ${Created}
**Scope:** ${Scope}
## Methodology
EOF
cat "${PROJECTDIR}/methodology.md" >> "${REPORT}"
printf "${GREEN}[+]Base report set, crawling targets\n"


# --- Helper: extract a flat block (PORTS, CREDS, SESSION, SERVICES, EMAILS) ---
extract_block() {
    local marker="$1"
    local conf_file="$2"
    sed -n "/#${marker}_START/,/#${marker}_END/{//!p}" "$conf_file"
}

# --- Helper: VULNS block -> markdown table (DATE|VULN|SEVERITY|DESCRIPTION) ---
print_vulns_table() {
    local conf_file="$1"
    local vulns
    vulns=$(extract_block "VULNS" "$conf_file")

    if [[ -n "$vulns" ]]; then
        echo "| Date | Vulnerability | Severity | Description |" >> "${REPORT}"
        echo "|------|---------------|----------|--------------|" >> "${REPORT}"
        while IFS='|' read -r date vuln severity desc; do
            [[ -n "$date" ]] || continue
            echo "| ${date} | ${vuln} | ${severity} | ${desc} |" >> "${REPORT}"
        done <<< "$vulns"
    else
        echo "_No vulnerabilities recorded._" >> "${REPORT}"
    fi
}

# --- Appendix setup ---

printf "${GREEN}[+] Preparing appendix\n${NC}"
echo "# Appendix: Attack Results" > "$APPENDIX"

# --- Main per-target loop ---
for TARGET_PATH in "${PROJECTDIR}/targets"/*/; do
    TARGET_CONF="${TARGET_PATH}target.conf"
    [[ -f "$TARGET_CONF" ]] || continue

    # reset vars so stale values don't leak between targets
    unset TARGETIP TARGETURL DISCOVERED
    source "$TARGET_CONF"
    printf "${GREEN}[+][+] Crawling ${TARGETURL} ${TARGETIP}\n${NC}"
    cat >> "${REPORT}" << EOF

## Target: ${TARGETURL} (${TARGETIP})
- Discovered: ${DISCOVERED}

### Ports
$(extract_block "PORTS" "$TARGET_CONF")

### Services
$(extract_block "SERVICES" "$TARGET_CONF")

### Emails
$(extract_block "EMAILS" "$TARGET_CONF")

### Credentials
$(extract_block "CREDS" "$TARGET_CONF")

### Sessions
$(extract_block "SESSION" "$TARGET_CONF")

### Vulnerabilities
EOF

    print_vulns_table "$TARGET_CONF"

    echo "" >> "${REPORT}"
    echo "### Attacks Run" >> "${REPORT}"

    ATTACKS_DIR="${TARGET_PATH}attacks"

    if [[ -d "$ATTACKS_DIR" ]]; then
        # --- List each attack run as "TIMESTAMP - ATTACKTYPE" ---
        for ATTACK_RUN in "$ATTACKS_DIR"/*/; do
            [[ -d "$ATTACK_RUN" ]] || continue
            RUN_NAME=$(basename "$ATTACK_RUN")

            # Directory format assumed: YYYYMMDD_HHMMSS_ATTACKTYPE
            TIMESTAMP=$(cut -d'_' -f1,2 <<< "$RUN_NAME")
            ATTACK_TYPE=$(cut -d'_' -f3- <<< "$RUN_NAME")

            echo "- ${TIMESTAMP} - ${ATTACK_TYPE}" >> "${REPORT}"
        done

        # --- Embed any PNGs found anywhere under this target's attacks ---
        while IFS= read -r -d '' PNG; do
            echo "" >> "${REPORT}"
            echo "![$(basename "$PNG")]($PNG)" >> "${REPORT}"
        done < <(find "$ATTACKS_DIR" -iname "*.png" -print0)

        # --- Appendix: list every file per attack run, grouped by target ---
        APPENDIX="${PROJECTDIR}/appendix.md"
        echo "" >> "$APPENDIX"
        echo "## ${TARGETURL}" >> "$APPENDIX"

        for ATTACK_RUN in "$ATTACKS_DIR"/*/; do
            [[ -d "$ATTACK_RUN" ]] || continue
            RUN_NAME=$(basename "$ATTACK_RUN")

            echo "" >> "$APPENDIX"
            echo "### ${RUN_NAME}" >> "$APPENDIX"

            find "$ATTACK_RUN" -type f | while read -r FILE; do
                echo "- ${FILE}" >> "$APPENDIX"
            done
        done
    fi
done

echo "" >> "${REPORT}"
echo "---" >> "${REPORT}"
echo "See [Appendix: Attack Results](appendix.md) for full file listings." >> "${REPORT}"