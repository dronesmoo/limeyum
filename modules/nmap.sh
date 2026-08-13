#!/bin/bash

# Nmap → Nuclei → Searchsploit (off Nuclei results) automation

parse_services() {
    local xml="${outfile}.xml"

    xmllint --xpath '//port[state/@state="open"]' "$xml" 2>/dev/null \
    | while IFS= read -r line; do
        PORT=$(echo "$line"    | grep -oP '(?<=portid=")[^"]+')
        PROTO=$(echo "$line"   | grep -oP '(?<=name=")[^"]+')
        PRODUCT=$(echo "$line" | grep -oP '(?<=product=")[^"]+')
        VERSION=$(echo "$line" | grep -oP '(?<=version=")[^"]+')

        [[ -z "$PRODUCT" ]] && PRODUCT="$PROTO"

        sed -i "/#PORTS_END/i #Port:#${PORT}:#${PROTO}:#${PRODUCT}:#${VERSION}" \
            "$TARGET_DIR/target.conf"
    done
}

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[38;5;39m'
NC='\033[0m'

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
TARGET_DIR="$1"
if [[ -z "${TARGET_DIR}/target.conf" ]]; then
    echo -e "${RED}No target.conf found at $TARGET_DIR${NC}"
    read -p "Target IP: " TARGETIP
    read -p "Target URL: " TARGETURL

else
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$TARGET_DIR/target.conf"   # now $TARGETIP, $TARGETURL, etc. are set
fi
ATTACKMODULE="nmap"

if [[ -n "$TARGETIP" && -n "$TARGETURL" ]]; then
    read -p "Target IP or URL? (IP/URL): " IPORURL
    if [[ "$IPORURL" == "IP" ]]; then
        target="${TARGETIP}"
    else
        target="${TARGETURL}"
    fi
elif [[ -n "$TARGETIP" ]]; then
    target="${TARGETIP}"
elif [[ -n "$TARGETURL" ]]; then
    target="${TARGETURL}"
fi

echo -e "${GREEN}[+] Target: $target${NC}" 
echo -e "$TIMESTAMP: Enumeration - $target - NMAP" >> "../$TARGET_DIR/methodology.md"
echo -e "1. Speed: 1. Invisible  2. Ninja  3. Standard  4. Fast"
    read -e -p "   Select speed [1-4]: " speed_choice
    case "$speed_choice" in
        1) speed_flags="-T0 -sS -Pn" ;;          # invisible: slow, stealthy
       #)ces (y/n)? " CHECKEXPLOITS
#<can of ${target} (${port_flags}),1-5 with flags: ${speed_flags}${NC}"
#<peed
        2) speed_flags="-T1 -sS -Pn" ;;           # ninja: quieter
        3) speed_flags="-T3 -sS" ;;               # standard
        4) speed_flags="-T4 -sS" ;;               # fast
        *) speed_flags="-T3 -sS" ;;
    esac

    echo
    echo "2 Ports:  1. Webapp  2. Linux  3. Windows  4. DNS  5. Mail  6. All  7. Custom"
    read -e -p "   Select ports [1-7]: " port_choice
    case "$port_choice" in
        1) port_flags="-p 80,443,8080,8443" ;;
        2) port_flags="-p 22,111,2049,3306,5432" ;;
        3) port_flags="-p 135,139,445,3389,5985" ;;
        4) port_flags="-p 53" ;;
        5) port_flags="-p 25,110,143,465,587,993,995" ;;
        6) port_flags="-p-" ;;
        7) read -e -p "   Enter custom port spec (e.g. 22,80,1000-2000): " custom_ports
           port_flags="-p ${custom_ports}" ;;
        *) port_flags="-p-" ;;
    esac
    outdir="${TARGET_DIR}/attacks/NMAP-${TIMESTAMP}"
    mkdir "${outdir}"
    outfile="${outdir}/NMAP-${TIMESTAMP}_initial"

    echo
    echo -e "${BLUE} [+] Starting NMAP scan of ${target} (${port_flags}) with flags: ${speed_flags} -Pn"
    bash -c "nmap  -Pn  ${speed_flags} ${port_flags} -oA ${outfile} ${target}" >/dev/null  2>&1 &
    NMAP_PID=$!
    spin() {
    local SPINNER=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0
    echo -e "${YELLOW}"
    while kill -0 $NMAP_PID 2>/dev/null; do
        PERCENT=$(grep -oP 'percent="\K[^"]+' "${outfile}.xml" 2>/dev/null | tail -1)
        PERCENT=${PERCENT:-0}
        
        printf "\r[*] %s%% %s  " "$PERCENT" "${SPINNER[$i]}"
        
        i=$(( (i + 1) % ${#SPINNER[@]} ))
        sleep 0.1
    done
    echo -e "${GREEN}"
    printf "\r[+] 100%%  ✓                       \n"
}
spin
wait "$NMAP_PID" 
echo -e "${BLUE}[+] Updating Target Config with Results"
parse_services 
echo -e "${GREEN}[+] Target Config updated${NC}"



    echo -e "${GREEN}[+] NMAP Scan Complete${NC}"
    cat "${outfile}.nmap"
    echo "    1 to scan found ports with scripts, 2 to enumerate website, 3 for other attack options"
    read -e -p "Selection: " post_choice
    case "$post_choice" in
        1) read -p "Check for exploits on found services y/n? " CHECKEXPLOITS
        echo -e "${BLUE}[+] Starting NMAP Script scan of ${target} (${port_flags}),1-5 with flags: ${speed_flags}${NC}"
        bash -c "nmap -sV -sC -O ${port_flags} ${speed_flags} -p 1-5 -oA ${outfile}_scripts $target"  >/dev/null  2>&1 &
         NMAP_PID=$!
    spin() {
    local SPINNER=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0
    echo -e "${YELLOW}"
    while kill -0 $NMAP_PID 2>/dev/null; do
        PERCENT=$(grep -oP 'percent="\K[^"]+' "${outfile}_scripts.xml" 2>/dev/null | tail -1)
        PERCENT=${PERCENT:-0}

        printf "\r[*] %s%% %s  " "$PERCENT" "${SPINNER[$i]}"

"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        i=$(( (i + 1) % ${#SPINNER[@]} ))
        sleep 0.1
    done
    echo -e "${GREEN}"
    printf "\r[+] 100%%  ✓                    \n"
}

spin
wait "${NMAP_PID}"
    grep -oP '<service[^>]*/>' '${outputfile}_scripts.xml | while read -r line; do
    NAME=$(echo "$line" | grep -oP 'name="\K[^"]*')
    VERSION=$(echo "$line" | grep -oP 'version="\K[^"]*')
    [[ -n "$NAME" ]] && echo "| #${NAME} | #${VERSION} |" >> "${TARGET_DIR}/target.conf
    sed -i "/#SERVICES_END/i ${ENTRY}" "${TARGET_DIR}/target.conf"
done
echo -e "${GREEN}"
echo "=== NMAP SCAN COMPLETE ==="
if [[ CHECKEXPLOITS == "y" ]]; then
       bash -c " ${SCRIPT_DIR}/vulnerability_scan.sh  ${TARGET}"
    fi
         ;;
        2) echo "[+] Starting external enum package"
           bash -c "${SCRIPT_DIR}/externalenum.sh ${TARGET}" ;;
        3) bash -c "../${SCRIPT_DIR}/lib/attack.sh ${TARGET}" ;;
        back) : ;;
    esac




