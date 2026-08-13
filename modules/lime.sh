#!/bin/bash

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[38;5;39m'
NC='\033[0m'

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

echo -e "${BLUE}[+] limeyum scouting on $(hostname) - $(date)${NC}"
echo "Full map saved to limeyum-$(hostname).txt"
exec > >(tee "limeyum-$(hostname).txt") 2>&1

echo -e "\n${BLUE}=== USER & CONTEXT ===${NC}"
id
whoami

echo -e "\n${BLUE}=== NON-INTERACTIVE SUDO (key signal) ===${NC}"
sudo -l -n 2>/dev/null || echo "No passwordless sudo"

echo -e "\n${BLUE}=== SHELLS & PATH ===${NC}"
cat /etc/shells 2>/dev/null | tail -5 || echo "No shells file"
which bash 2>/dev/null || echo -e "${YELLOW}No bash → container/restricted likely${NC}"
echo -e "${YELLOW}PATH:${NC} $PATH"

echo -e "\n${BLUE}=== OS & KERNEL ===${NC}"
cat /etc/os-release 2>/dev/null
uname -a

echo -e "\n${BLUE}=== USERS WITH SHELLS ===${NC}"
cat /etc/passwd | grep -E "/bin/(ba)?sh" || echo "Limited shells"

echo -e "\n${BLUE}=== ROOT-OWNED WRITABLE (by current user) - FILES ===${NC}"
find / -user root -writable -type f 2>/dev/null | head -30

echo -e "\n${BLUE}=== ROOT-OWNED WRITABLE (by current user) - DIRS ===${NC}"
find / -user root -writable -type d 2>/dev/null | head -20

echo -e "\n${BLUE}=== KEY DIR LISTINGS ===${NC}"
ls -la /tmp /var/tmp /dev/shm 2>/dev/null

echo -e "\n${BLUE}=== ROOT PROCESSES (ancillary container/security signal) ===${NC}"
ps aux | grep -E "root|docker|containerd|kube|apparmor|selinux" | head -30

echo -e "\n${BLUE}=== CRON ===${NC}"
ls -la /etc/crontab 2>/dev/null
cat /etc/crontab 2>/dev/null

echo -e "\n${BLUE}=== BACKUPS & CONFIGS ===${NC}"
find / -name "*.bak" -o -name "*.old" 2>/dev/null | head -10
find /etc -name "*conf*" 2>/dev/null | head -15

echo -e "\n${BLUE}=== ANCILLARY SIGNALS (from sudo/ps + env) ===${NC}"
echo "→ Check root processes above for docker/containerd (container env)"
echo "→ AppArmor/SELinux/seccomp mentions in ps/sudo = restricted"
[ -f /.dockerenv ] && echo -e "${YELLOW}Docker container flag present${NC}"
cat /proc/1/cgroup 2>/dev/null | grep -E "docker||container" && echo -e "${YELLOW}Container cgroup detected${NC}"
cat /proc/self/status 2>/dev/null | grep -E "Seccomp|Cap" | head -5

echo -e "\n${BLUE}=== Network Items ===${NC}"
ip a

echo -e "\n${BLUE}=== SS (netcat) Items ===${NC}"
echo -e "${GREEN}[+] Summary:${NC}"
ss -s

echo -e "${GREEN}[+] Full Response:${NC}"
ss -lapn

echo -e "\n${BLUE}=== Common AD / Kubernetes Files ===${NC}"

# --- Active Directory indicators ---
echo -e "\n${GREEN}[+] AD-related config files${NC}"
find /etc -name "sssd.conf" 2>/dev/null
find /etc -name "krb5.conf" 2>/dev/null
find /etc -name "realmd.conf" 2>/dev/null
ls -la /etc/krb5.keytab 2>/dev/null
ls -la /etc/sssd/ 2>/dev/null

echo -e "\n${GREEN}[+] Keytab files${NC}"
find / -name "*.keytab" 2>/dev/null

echo -e "\n${GREEN}[+] Samba / AD domain join indicators${NC}"
if [ -f /etc/samba/smb.conf ]; then
    grep -iE "security\s*=\s*ads|realm\s*=|workgroup\s*=" /etc/samba/smb.conf 2>/dev/null
else
    echo "  /etc/samba/smb.conf not found"
fi

echo -e "\n${GREEN}[+] nsswitch AD indicators${NC}"
grep -E "sss|winbind|ldap" /etc/nsswitch.conf 2>/dev/null

# --- Kubernetes indicators ---
echo -e "\n${GREEN}[+] Kubernetes config & admin files${NC}"
find / -name "kubeconfig" -o -name "admin.conf" -o -name "kubelet.conf" 2>/dev/null | head -20
ls -la ~/.kube/config 2>/dev/null
ls -la /etc/kubernetes/ 2>/dev/null
ls -la /etc/kubernetes/manifests/ 2>/dev/null
ls -la /etc/kubernetes/pki/ 2>/dev/null

echo -e "\n${GREEN}[+] Kubernetes service account token${NC}"
ls -la /run/secrets/kubernetes.io/serviceaccount/ 2>/dev/null
ls -la /var/run/secrets/kubernetes.io/serviceaccount/ 2>/dev/null


echo -e "\n${GREEN}[+] Search complete.${NC}"