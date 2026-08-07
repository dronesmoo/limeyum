#!/bin/bash

RED=$'\033[0;31m'
YELLOW=$'\033[1;33m'
GREEN=$'\033[0;32m'
BLUE=$'\033[0;34m'
NC=$'\033[0m'

echo "${GREEN}Welcome to LIMEYum Installer.${NC}"
echo "Please note that some commands may require sudo rights."
echo "It is recommended to run ${YELLOW}sudo lime${NC} after installation for full functionality."
echo

# Validate path exists before proceeding
read -p "Install path: " THISPATH
if [[ ! -d "$THISPATH" ]]; then
    echo "${RED}[-] Path does not exist: $THISPATH${NC}"
    exit 1
fi


# Create structure
echo "${GREEN}[+] Creating directory structure...${NC}"
mkdir -p "$THISPATH"/{projects,modules,lib,templates} || {
    echo "${RED}[-] Failed to create directories. Check permissions.${NC}"
    exit 1
}

# Copy files
echo "[+] Installing files..."
cp lime.sh "$THISPATH/"
cp -r modules/* "$THISPATH/modules/" 2>/dev/null
cp -r lib/* "$THISPATH/lib/" 2>/dev/null
#cp -r templates/* "$THISPATH/templates/" 2>/dev/null
echo "[+] Updating file permissions"
chmod +x ./modules/*
chmod +x limeyum
echo "[+] LIIMEYum file permissions updated"

# Create symlink so `lime` works from anywhere
echo "[+] Creating symlink..."
ln -sf "$THISPATH/limeyum/limeyum" /usr/local/bin/limeyum
chmod +x "$THISPATH/limeyum/limeyum"

# Check for optional dependencies
echo
echo "[+] Checking dependencies..."
for tool in nmap curl jq searchsploit nuclei pandoc zaproxy; do
    if command -v "$tool" &>/dev/null; then
        echo "  ${GREEN}✓${NC} $tool"
    else
        echo "  ${YELLOW}!${NC} $tool not found (optional -- needed for some modules)"
    fi
done

echo
echo "${GREEN}[+] LIMEYum installed successfully.${NC}"
echo "[+] Installed to: $THISPATH/limeyum"
echo "[+] Run with: ${YELLOW}sudo limeyum${NC}"
