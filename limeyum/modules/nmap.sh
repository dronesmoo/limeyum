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
        
        sed -i "/#PORTS_END/i Port:${PORT}:${PROTO}:${PRODUCT}:${VERSION}" \
            "$TARGET_DIR/target.conf"
    done
}
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
TARGET="$1"
if [[ ! -f "$TARGET_DIR/target.conf" ]]; then
    echo "${RED}No target.conf found at $TARGET_DIR${NC}"
    read -p "Target IP: " TARGETIP
    read -p "Target URL: " TARGETURL

else
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$TARGET_DIR/target.conf"   # now $TARGETIP, $TARGETURL, etc. are set
echo "$TIMESTAMP: Enumeration - $TARGET - NMAP" >> "../$TARGET_DIR/methodology.md"
fi
echo "${GREEN}[+]Target set${NC}"
echo "1. Speed: 1. Invisible  2. Ninja  3. Standard  4. Fast"
    read -e -p "   Select speed [1-4]: " speed_choice
    case "$speed_choice" in
        1) speed_flags="-T0 -sS -Pn" ;;          # invisible: slow, stealthy
        2) speed_flags="-T2 -sS -Pn" ;;           # ninja: quieter
        3) speed_flags="-T3 -sS" ;;               # standard
        4) speed_flags="-T4 -sS" ;;               # fast
        *) speed_flags="-T3 -sS" ;;
    esac

    echo
    echo "2. Ports: 1. Webapp  2. Linux  3. Windows  4. DNS  5. Mail  6. All  7. Custom"
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
   outdir="${TARGET}/attacks/NMAP-${TIMESTAMP}"
    outfile="${outdir}/NMAP-${TIMESTAMP}_initial"
 
    echo
    echo "${BLUE}[+] Starting NMAP scan of ${target} (${port_flags}) with flags: ${speed_flags}${NC}"
    nmap -v0 ${speed_flags} ${port_flags} -oA "${outfile}" "${target}" --noninteractive 2>/dev/null &
    NMAP_PID=$!
    spin() {
    local SPINNER=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0
    echo "${YELLOW}
    while kill -0 $NMAP_PID 2>/dev/null; do
        PERCENT=$(grep -oP 'percent="\K[^"]+' "${outfile}.xml" 2>/dev/null | tail -1)
        PERCENT=${PERCENT:-0}
        
        printf "\r[*] %s%% %s  " "$PERCENT" "${SPINNER[$i]}"
        
        i=$(( (i + 1) % ${#SPINNER[@]} ))
        sleep 0.1
    done
    echo "${GREEN}
    printf "\r[+] 100%%  ✓                    \n"
}
 
echo "${BLUE}[+] Updating Target Config with Results"
parse_services 
echo "${GREEN}[+] Target Config updated${NC}"



    echo "${GREEN}[+] NMAP Scan Complete${NC}"
    echo "    1 to scan found ports with scripts, 2 to enumerate website, 3 for other attack options"
    read -e -p "$(build_prompt)" post_choice
    case "$post_choice" in
        1) read -p "Check for exploits on found services (y/n)? " CHECKEXPLOITS
        echo "${BLUE}[+] Starting NMAP Script scan of ${target} (${port_flags}),1-5 with flags: ${speed_flags}${NC}"
        nmap -sV -sC -O ${port_flags} ${speed_flags} -p 1-5 -oA "${outfile}_scripts" "$target" --noninteractive 2>/dev/null &
         NMAP_PID=$!
    spin() {
    local SPINNER=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0
    echo "${YELLOW}
    while kill -0 $NMAP_PID 2>/dev/null; do
        PERCENT=$(grep -oP 'percent="\K[^"]+' "${outfile}.xml" 2>/dev/null | tail -1)
        PERCENT=${PERCENT:-0}
        
        printf "\r[*] %s%% %s  " "$PERCENT" "${SPINNER[$i]}"
        
        i=$(( (i + 1) % ${#SPINNER[@]} ))
        sleep 0.1
    done
    echo "${GREEN}
    printf "\r[+] 100%%  ✓                    \n"
}
    echo
    echo "${GREEN}[+] NMAP Scan Complete${NC}"
    if [[ CHECKEXPLOITS == "y" ]]; then
        $HOME/modules/vulnerability_scan.sh $
    fi
         ;;
        2) echo "[+] Starting external enum package"
            $HOME/modules/externalenum.sh ${TARGET} ;;
        3) $HOME/modules/attack.sh ${TARGET} ;;
        back) : ;;
    esac

    pop_ctx   # pop Target
    pop_ctx   # pop nmap
# Nuclei on web services
grep -E "80/open|443/open|http" scan_full.nmap 2>/dev/null | awk '{print $NF}' > http_targets.txt || touch http_targets.txt
echo "[+] Running Nuclei on discovered web services..."
nuclei -l http_targets.txt -severity critical,high,medium -o nuclei_results.txt -stats -silent

# 3. Searchsploit using Nuclei results
echo "[+] Running Searchsploit based on Nuclei findings..."
if [ -s nuclei_results.txt ]; then
    # Extract potential CVEs or keywords from Nuclei
    grep -oE 'CVE-[0-9]{4}-[0-9]+' nuclei_results.txt | sort -u > cve_list.txt
    echo "[+] Found CVEs from Nuclei: $(wc -l < cve_list.txt)"
    
    # Searchsploit on CVEs + service names
    if [ -s cve_list.txt ]; then
        while read -r cve; do
            searchsploit "$cve" >> searchsploit_from_nuclei.txt
        done < cve_list.txt
    fi
    
    # Fallback: Searchsploit on full nmap too
    searchsploit --nmap scan_full.xml >> searchsploit_from_nuclei.txt
else
    echo "[-] No Nuclei results. Falling back to nmap XML..."
    searchsploit --nmap scan_full.xml > searchsploit_from_nuclei.txt
fi

echo ""
echo "=== Pipeline Complete ==="
echo "Check these key files:"
echo "  - nuclei_results.txt (vuln detections)"
echo "  - searchsploit_from_nuclei.txt (exploits from Nuclei findings)"
echo "  - scan_full.nmap / detailed.nmap"
ls -l
