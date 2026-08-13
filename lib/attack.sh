# lib/attack.sh
#!/bin/bash

TARGET_DIR="$1"
if [[ ! -f "$TARGET_DIR/target.conf" ]]; then
    echo "${RED}No target.conf found at $TARGET_DIR${NC}"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$TARGET_DIR/target.conf"   
ATTACKMODULE=""
ATTACK_DIR="$(cd "$SCRIPT_DIR/../modules" && pwd)"

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[38;5;39m'
NC='\033[0m'

echo "${BLUE}Attacking $TARGETIP ($TARGETURL)."
echo "Please select your attack:${NC}"
    i=0
    options=()
    while IFS= read -r line; do
        i=$((i + 1))
        options+=("$line")
        echo "$i. ${line%.sh}"
    done < <(ls "${ATTACK_DIR}" | grep '\.sh$' | grep -vE '^(attack|report)\.sh$')

    if [[ $i -eq 0 ]]; then
        echo -e "${RED}No attack modules found in ./modules${NC}"
    else
        read -p "Attack module: " ATTACKMODULE
        MODULE_NAME="${options[$((ATTACKMODULE - 1))]}"

        if [[ -z "$MODULE_NAME" ]]; then
            echo -e "${RED}Invalid selection.${NC}"
        else
            echo -e "${BLUE}Starting ${MODULE_NAME%} attack module...${NC}"
            bash -c "${ATTACK_DIR}/${MODULE_NAME} ${TARGET_DIR}"
        fi
    fi