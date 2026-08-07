#!/bin/bash

RED=$'\033[0;31m'
YELLOW=$'\033[1;33m'
GREEN=$'\033[0;32m'
BLUE=$'\033[0;34m'
NC=$'\033[0m'

echo "${BLUE}Let's FUZZ!${NC}"

TARGET_DIR="$1"
if [[ ! -f "$TARGET_DIR/target.conf" ]]; then
    echo "${RED}No target.conf found at $TARGET_DIR${NC}"
    read -p "Target IP: " TARGETIP
    read -p "Target URL: " TARGETURL

else
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$TARGET_DIR/target.conf"   # now $TARGETIP, $TARGETURL, etc. are set
fi
echo "${GREEN}[+]Target set${NC}"
read -p "Use URL or IP: " URLORIP
URLORIP="${URLORIP^^}"

declare -A IPORURLCHOICE=(
    [IP]="${TARGETIP}"
    [URL]="${TARGETURL}"
)
declare -A DEFAULTWORDLISTS=(
    [1]="/usr/share/wordlists/seclists/Discovery/DNS/subdomains-top1million-5000.txt"
    [2]="/usr/share/wordlists/seclists/Discovery/Web-Content/directory-list-2.3-medium.txt"
    [3]="/usr/share/wordlists/seclists/Discovery/Web-Content/raft-medium-files.txt"
    [4]="/usr/share/wordlists/seclists/Discovery/Web-Content/burp-parameter-names.txt|/usr/share/wordlists/seclists/Fuzzing/big-list-of-naughty-strings.txt"
)





echo ""

echo "Defaults:"
echo 'Speed: $SPEED'
echo: 'Wait time: $WAITTIME'
echo: 'Header: $DEFAULTHEADER'
read -p "Do you want to modify these defaults for only this run (y/n)? " MODDEFAULTS
if [[ MODDEFAULTS = y ]]; then
  read -p 'New speed (enter for default): ' NEWSPEED
  THISSPEED="${NEWSPEED:-$SPEED}"
  read -p 'New wait time (enter for default): ' NEWWAITTIME
  THISWAITTIME="${NEWWAITTIME:-$WAITTIME"
  read -p 'New header (enter for default): ' NEWHEADER
  THISDEFAULTHEADER="${NEWHEADER:-$DEFAULTHEADER}"
fi

echo "What do you want to fuzz?"
echo "1. Subdomains"
echo "2. Directories"
echo "3. File type"
echo "4. Key-Value pair"
echo "5. Other"
read -p "Your selection: " TYPE

read -p "Target domain (prefix with -f for a file containing a list of targets): " TARGET
read -p "Header (e.g. 'Authorization: Bearer xyz', optional): " HEADER_VALUE

read -p "Use default filters (200,300,301,403) (y/n)? " USE_DEFAULT
if [[ "$USE_DEFAULT" == "y" || "$USE_DEFAULT" == "Y" ]]; then
    FILTERS="200,300,301,403"
else
    read -p "   Enter status codes to accept (comma separated): " FILTERS
fi

read -p "Threads (default 5): " THREADS
THREADS=${THREADS:-5}

read -p "Enable baseline false-positive filtering, default y? (y/n): " BASELINE_CHOICE
if [[ "$BASELINE_CHOICE" == "n" || "$BASELINE_CHOICE" == "N" ]]; then
    BASELINE_ENABLED=false
else
    BASELINE_ENABLED=true
fi

if [[ "$TYPE" == "4" ]]; then
    KEYWORDLIST="${DEFAULTWORDLISTS[4]%%|*}"   # everything before |
    VALWORDLIST="${DEFAULTWORDLISTS[4]##*|}"   # everything after |
    read -p "Use default wordlist: Key: $(basename "${KEYWORDLIST}"), Value: $(basename "${VALWORDLIST}")  (y/n)? " USEDWL
    if [[ USEDWL == 'n' ]]; then
    read -p "Path to key wordlist: " KEYWORDLIST
    if [[ ! -f "$KEYWORDLIST" ]]; then
        echo "${RED}Wordlist not found: $WORDLIST${NC}"
        exit 1
    fi
    read -p "Path to value wordlist: " VALWORDLIST
    if [[ ! -f "$VALWORDLIST" ]]; then
        echo "${RED}Wordlist not found: $WORDLIST${NC}"
        exit 1
    fi
    fi
fi
else
    read -p "Use default wordlist: $(basename "${DEFAULTWORDLISTS[$TYPE]}") (y/n)? " USEDWL
    if [[ USEDWL == 'n' ]]; then
    read -p "Path to wordlist: " WORDLIST
    if [[ ! -f "$WORDLIST" ]]; then
        echo "${RED}Wordlist not found: $WORDLIST${NC}"
        exit 1
    fi
fi
fi



# --- Resolve target(s) ---
if [[ "$TARGET" == -f* ]]; then
    TARGET_FILE="${TARGET#-f}"
    TARGET_FILE="${TARGET_FILE# }"
    if [[ ! -f "$TARGET_FILE" ]]; then
        echo "${RED}Target file not found: $TARGET_FILE${NC}"
        exit 1
    fi
    mapfile -t TARGETS < "$TARGET_FILE"
else
    TARGETS=("$IPORURLCHOICE[$URLORIP]")
fi

# --- Build a URL template for a given target, based on fuzz type ---
build_template() {
    local t="$1"
    case $TYPE in
        1) echo "https://FUZZ.${t}" ;;
        2) echo "https://${t}/FUZZ" ;;
        3)
            if [[ -z "$EXT" ]]; then
                read -p "Extension (e.g. php): " EXT
            fi
            echo "https://${t}/FUZZ.${EXT}"
            ;;
        4)
            if [[ -z "$KV_TEMPLATE" ]]; then
                read -p "Full URL with FUZZ as placeholder for key or value (e.g. https://${t}/?FUZZ=test): " KV_TEMPLATE
            fi
            echo "$KV_TEMPLATE"
            ;;
        5)
            if [[ -z "$OTHER_TEMPLATE" ]]; then
                read -p "Full URL with FUZZ placeholder: " OTHER_TEMPLATE
            fi
            echo "$OTHER_TEMPLATE"
            ;;
        *)
            echo "${RED}Invalid selection${NC}" >&2
            exit 1
            ;;
    esac
}

FILTER_REGEX="^($(echo "$FILTERS" | sed 's/,/|/g'))$"
OUTFILE="fuzz_results_$(date +%Y%m%d_%H%M%S).txt"
> "$OUTFILE"

# --- Fetch a URL, return status|size|hash ---
fetch() {
    local url="$1"
    local args=(-s -w $'\n%{http_code}' --max-time 10)
    if [[ -n "$HEADER_VALUE" ]]; then
        args+=(-H "$HEADER_VALUE")
    fi
    local raw
    raw=$(curl "${args[@]}" "$url")
    local status="${raw##*$'\n'}"
    local body="${raw%$'\n'*}"
    local size=${#body}
    local hash
    hash=$(printf '%s' "$body" | md5sum | cut -d' ' -f1)
    printf '%s|%s|%s' "$status" "$size" "$hash"
}

# --- Sample a few random (non-wordlist) words to fingerprint the "not found" response ---
detect_baseline() {
    local template="$1"
    local hashes=()
    local statuses=()
    local i
    for i in 1 2 3; do
        local rand_word
        rand_word=$(tr -dc 'a-z0-9' </dev/urandom 2>/dev/null | head -c 14)
        local url="${template//FUZZ/$rand_word}"
        local result
        result=$(fetch "$url")
        statuses+=("${result%%|*}")
        hashes+=("${result##*|}")
    done

    # Only trust the baseline if all samples agree
    if [[ "${hashes[0]}" == "${hashes[1]}" && "${hashes[1]}" == "${hashes[2]}" ]]; then
        printf '%s' "${hashes[0]}"
    else
        printf ''
    fi
}

fuzz_worker() {
    local url="$1"
    local result
    result=$(fetch "$url")
    local status="${result%%|*}"
    local rest="${result#*|}"
    local size="${rest%%|*}"
    local hash="${rest##*|}"

    [[ ! "$status" =~ $FILTER_REGEX ]] && { sleep "$THISWAITTIME"; return; }

    if [[ "$BASELINE_ENABLED" == "true" && -n "$BASELINE_HASH" && "$hash" == "$BASELINE_HASH" ]]; then
        return
    else
            echo -e "${GREEN}[${status}]${NC} ${url} ${YELLOW}(size: ${size})${NC}"
    echo "[${status}] ${url} (size: ${size})" >> "$OUTFILE"

    fi
    sleep "$THISWAITTIME"

}
export -f fetch fuzz_worker

echo ""
echo "${BLUE}Starting fuzz with $THREADS threads every $THISWAITTIME seconds...${NC}"
echo ""

for t in "${TARGETS[@]}"; do
    [[ -z "$t" ]] && continue
    TEMPLATE=$(build_template "$t")

    BASELINE_HASH=""
    if [[ "$BASELINE_ENABLED" == "true" ]]; then
        BASELINE_HASH=$(detect_baseline "$TEMPLATE")
        if [[ -n "$BASELINE_HASH" ]]; then
            echo "${YELLOW}[${t}] Baseline detected — excluding responses matching hash ${BASELINE_HASH:0:8}...${NC}"
        else
            echo "${YELLOW}[${t}] Baseline responses inconsistent — filtering disabled for this target.${NC}"
        fi
    fi

    export HEADER_VALUE FILTER_REGEX BASELINE_ENABLED BASELINE_HASH RED GREEN YELLOW NC OUTFILE

    while IFS= read -r word; do
        echo "${TEMPLATE//FUZZ/$word}"
    done < "$WORDLIST" | xargs -P "$THREADS" -I{} bash -c 'fuzz_worker "$@"' _ {}
done

echo ""
echo "${BLUE}Done. Results saved to ${OUTFILE}${NC}"