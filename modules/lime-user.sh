#!/bin/bash
# limeyum-user.sh - Lightweight Linux enum focused on a specific user (lateral movement aid)
# Usage: ./limeyum-user.sh <username> [1 for stealth]

TARGET="$1"

TARGET_DIR="$2"
if [[ ! -f "$TARGET_DIR/target.conf" ]]; then
    echo "${RED}No target.conf found at $TARGET_DIR${NC}"
    read -p "Target IP: " TARGETIP
    read -p "Target URL: " TARGETURL

else
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$TARGET_DIR/target.conf"   # now $TARGETIP, $TARGETURL, etc. are set
fi
echo "${GREEN}[+]Target set${NC}"

STEALTH="${2:-0}"

if [ -z "$TARGET" ]; then
    echo "Usage: $0 <username> [1 for stealth]"
    exit 1
fi

# Validate user exists
if ! id "$TARGET" &>/dev/null; then
    echo "User '$TARGET' does not exist on this system."
    exit 1
fi

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

if [ "$STEALTH" -eq 1 ]; then
    export HISTFILE=/dev/null
    OUTPUT="/dev/stdout"
else
    OUTPUT="limeyum-${TARGET}-$(hostname).txt"
fi

echo -e "${BLUE}[+] limeyum-user scouting focused on: $TARGET  ($(date))${NC}"
echo "Output: $OUTPUT"
exec > >(tee "$OUTPUT") 2>&1

echo -e "\n${BLUE}=== TARGET USER CONTEXT ===${NC}"
id "$TARGET"
echo -e "${YELLOW}Groups:${NC}"
groups "$TARGET" 2>/dev/null
echo -e "${YELLOW}Home:${NC}"
getent passwd "$TARGET" | cut -d: -f6

echo -e "\n${BLUE}=== SUDO RIGHTS (if any) ===${NC}"
sudo -l -U "$TARGET" 2>/dev/null || echo "Cannot check sudo for $TARGET (or none)"

echo -e "\n${BLUE}=== PROCESSES RUNNING AS $TARGET ===${NC}"
ps aux | grep -E "^$TARGET| $TARGET " | grep -v grep | head -25

echo -e "\n${BLUE}=== FILES OWNED BY $TARGET (interesting locations) ===${NC}"
find /home /var /tmp /opt /etc -user "$TARGET" 2>/dev/null | head -40

echo -e "\n${BLUE}=== WRITABLE BY $TARGET (potential privesc / persistence) ===${NC}"
find / -user "$TARGET" -writable -type f 2>/dev/null | head -20
find / -user "$TARGET" -writable -type d 2>/dev/null | head -15

echo -e "\n${BLUE}=== HOME DIRECTORY LISTING ===${NC}"
HOME_DIR=$(getent passwd "$TARGET" | cut -d: -f6)
if [ -d "$HOME_DIR" ]; then
    ls -la "$HOME_DIR" 2>/dev/null
    echo -e "\n${YELLOW}Hidden / interesting files:${NC}"
    ls -la "$HOME_DIR"/.* 2>/dev/null | head -20
    find "$HOME_DIR" -name "*.ssh" -o -name "id_*" -o -name "*.key" -o -name "*password*" -o -name "*.bak" 2>/dev/null | head -15
else
    echo "Home directory not accessible or does not exist"
fi

echo -e "\n${BLUE}=== CRONTAB FOR $TARGET ===${NC}"
crontab -u "$TARGET" -l 2>/dev/null || echo "No crontab or permission denied"

echo -e "\n${BLUE}=== SSH ARTIFACTS ===${NC}"
find /home/"$TARGET" /root -name "authorized_keys" -o -name "id_rsa*" -o -name "known_hosts" 2>/dev/null | head -10

echo -e "\n${BLUE}=== GROUP MEMBERSHIPS & SHARED RESOURCES ===${NC}"
echo "Primary + supplementary groups:"
id -Gn "$TARGET"
echo -e "\n${YELLOW}Files/dirs writable by groups that $TARGET belongs to (sample):${NC}"
# Light sample of group-writable items
for g in $(id -Gn "$TARGET"); do
    find /home /var /tmp -group "$g" -writable 2>/dev/null | head -5
done

echo -e "\n${BLUE}=== QUICK SYSTEM CONTEXT (original limeyum style) ===${NC}"
echo -e "${YELLOW}Current user running this scan:${NC}"
id
echo -e "${YELLOW}Kernel / OS:${NC}"
uname -a
cat /etc/os-release 2>/dev/null | head -5

echo -e "\n${GREEN}[+] Focused scouting on $TARGET complete.${NC}"
echo "Review home, processes, writable items, and group access for lateral movement paths."