#!/bin/bash

RED=$'\033[0;31m'
YELLOW=$'\033[1;33m'
GREEN=$'\033[0;32m'
BLUE=$'\033[38;5;39m'
NC=$'\033[0m'

REPO_URL="https://github.com/dronesmoo/limeyum.git"

echo "${GREEN}Welcome to LIMEYum Installer.${NC}"
echo "Please note that some commands may require sudo rights."
echo "It is recommended to run ${YELLOW}sudo limeyum${NC} after installation for full functionality."
echo


read -p "Install path: " THISPATH
# Create structure
echo "${GREEN}[+] Creating directory structure...${NC}"
mdkir -p "$THISPATH"
mkdir -p "$THISPATH"/{projects,modules,lib,templates} || {
    echo "${RED}[-] Failed to create directories. Check permissions.${NC}"
    exit 1
}
bash -c "cd ${THISPATH}"

# Copy files
printf "${BLUE}[+] Installing files...\n"
echo "Cloning limeyum..."
git clone "$REPO_URL" "$INSTALL_DIR"
echo "[+] Updating file permissions"
chmod +x ./modules/*
chmod +x ./lib/*
chmod +x limeyum
echo "[+] LIIMEYum file permissions updated"

# Create symlink so `lime` works from anywhere
echo "[+] Creating symlink..."
ln -sf "$THISPATH/limeyum/limeyum" /usr/local/bin/limeyum

# Check for optional dependencies
echo
echo "[+] Checking dependencies..."
touch dependencies.txt
ND="FALSE"
for tool in nmap curl jq searchsploit nuclei pandoc zaproxy kerbrute; do
    if command -v "$tool" &>/dev/null; then
        echo "  ${GREEN}✓${NC} $tool"
    else
        echo "  ${YELLOW}!${NC} $tool not found (optional -- needed for some modules)"
        echo "${tool}" >> dependencies.txt
        ND="TRUE"
    fi
done
if [[ $ND == "TRUE" ]]; then
read -p "Install missing dependencies (y/n)? " INMI
  if [[ $INMI == "y" ]]; then
    sudo apt update
    sudo apt install -y $(cat dependencies.txt)
  fi
fi

printf "${BLUE}[+] Cleaning up install files"
rm dependencies.txt

echo
echo "${GREEN}[+] LIMEYum installed successfully. To upate, re-run this script.${NC}"
echo "[+] Installed to: $THISPATH/limeyum"
echo "[+] Run with: ${YELLOW}sudo limeyum${NC}"