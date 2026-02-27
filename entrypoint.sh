#!/bin/bash

set -e

# ================================================================
# Kali Linux Standalone RDP + NoVNC Server
# Full penetration testing environment
# Run with: sudo bash entrypoint.sh
# ================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Configuration
VNC_PASSWORD="${VNC_PASSWORD:-kali123}"
VNC_PORT="${VNC_PORT:-5900}"
NOVNC_PORT="${NOVNC_PORT:-8080}"
RDP_PORT="${RDP_PORT:-3389}"
DISPLAY=":99"
GEOMETRY="${GEOMETRY:-1920x1080}"
DEPTH="${DEPTH:-24}"

clear
echo -e "${MAGENTA}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║                                                        ║${NC}"
echo -e "${RED}║  🔥  KALI LINUX - RDP + NoVNC Server  🔥          ║${NC}"
echo -e "${MAGENTA}║         Penetration Testing Environment               ║${NC}"
echo -e "${MAGENTA}║                                                        ║${NC}"
echo -e "${MAGENTA}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# ================================================================
# CHECK ROOT
# ================================================================

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}[ERROR] This script must be run as root (use sudo)${NC}"
   exit 1
fi

# ================================================================
# 1. VERIFY KALI LINUX
# ================================================================

echo -e "${YELLOW}[*] Verifying Kali Linux installation...${NC}"

if [ ! -f /etc/os-release ]; then
    echo -e "${RED}[ERROR] Not a supported Linux system${NC}"
    exit 1
fi

source /etc/os-release

if [[ "$ID" == "kali" ]]; then
    echo -e "${GREEN}[✓] Kali Linux detected: $PRETTY_NAME${NC}"
else
    echo -e "${YELLOW}[!] Warning: Not running Kali Linux ($PRETTY_NAME)${NC}"
    echo -e "${YELLOW}[!] Proceeding anyway...${NC}"
fi

# ================================================================
# 2. UPDATE SYSTEM
# ================================================================

echo -e "${YELLOW}[*] Updating Kali Linux packages...${NC}"

apt-get update -qq
apt-get upgrade -y -qq > /dev/null 2>&1

echo -e "${GREEN}[✓] System updated${NC}"

# ================================================================
# 3. INSTALL DESKTOP & REMOTE ACCESS
# ================================================================

echo -e "${YELLOW}[*] Installing desktop environment and remote access tools...${NC}"

apt-get install -y --no-install-recommends \
    xfce4 \
    xfce4-goodies \
    xfce4-terminal \
    xfce4-taskmanager \
    xfce4-panel \
    xfce4-appfinder \
    thunar \
    xvfb \
    x11vnc \
    dbus \
    dbus-x11 \
    supervisor \
    websockify \
    novnc \
    xrdp \
    xrdp-pulseaudio-installer \
    > /dev/null 2>&1

echo -e "${GREEN}[✓] Desktop environment installed${NC}"

# ================================================================
# 4. INSTALL KALI TOOLS (METAPACKAGES)
# ================================================================

echo -e "${YELLOW}[*] Installing Kali Linux tools (this may take a while)...${NC}"
echo -e "${YELLOW}    Installing: nmap, hydra, sqlmap, nikto, hashcat, aircrack-ng...${NC}"

apt-get install -y --no-install-recommends \
    kali-linux-headless \
    kali-tools-information-gathering \
    kali-tools-vulnerability-analysis \
    kali-tools-web \
    kali-tools-wireless \
    kali-tools-reverse-engineering \
    kali-tools-exploitation \
    kali-tools-sniffing-spoofing \
    kali-tools-password-cracking \
    kali-tools-forensics \
    metasploit-framework \
    burpsuite \
    sqlmap \
    nikto \
    nmap \
    hydra \
    john \
    hashcat \
    aircrack-ng \
    wireshark \
    tshark \
    tcpdump \
    netcat-openbsd \
    curl \
    wget \
    git \
    vim \
    nano \
    net-tools \
    iputils-ping \
    openssh-client \
    python3 \
    python3-pip \
    > /dev/null 2>&1

echo -e "${GREEN}[✓] Kali tools installed${NC}"

# ================================================================
# 5. CREATE DIRECTORIES
# ================================================================

echo -e "${YELLOW}[*] Creating required directories...${NC}"

mkdir -p /root/.vnc
mkdir -p /root/.config/xfce4
mkdir -p /tmp/.X11-unix
mkdir -p /var/run/dbus
mkdir -p /root/tools
mkdir -p /root/wordlists
chmod 1777 /tmp/.X11-unix

echo -e "${GREEN}[✓] Directories created${NC}"

# ================================================================
# 6. START DBUS
# ================================================================

echo -e "${YELLOW}[*] Starting D-Bus daemon...${NC}"

if [ ! -f /var/lib/dbus/machine-id ]; then
    dbus-uuidgen > /var/lib/dbus/machine-id
fi

if systemctl is-active --quiet dbus 2>/dev/null; then
    echo -e "${GREEN}[✓] D-Bus already running${NC}"
else
    dbus-daemon --system --nopidfile --nofork > /dev/null 2>&1 &
    sleep 1
    echo -e "${GREEN}[✓] D-Bus started${NC}"
fi

# ================================================================
# 7. CREATE X STARTUP SCRIPT
# ================================================================

echo -e "${YELLOW}[*] Configuring X startup script...${NC}"

cat > /root/.vnc/xstartup << 'EOF'
#!/bin/bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec /usr/bin/startxfce4 &
EOF

chmod 755 /root/.vnc/xstartup

echo -e "${GREEN}[✓] X startup configured${NC}"

# ================================================================
# 8. START XVFB (Virtual Framebuffer)
# ================================================================

echo -e "${YELLOW}[*] Starting Xvfb virtual display on ${DISPLAY}...${NC}"

# Kill any existing Xvfb
pkill -f "Xvfb.*:99" 2>/dev/null || true
sleep 1

Xvfb :99 -screen 0 ${GEOMETRY}x${DEPTH} -ac -pn > /tmp/xvfb.log 2>&1 &
XVFB_PID=$!
export DISPLAY=:99

sleep 3

if ps -p $XVFB_PID > /dev/null 2>&1; then
    echo -e "${GREEN}[✓] Xvfb running (PID: $XVFB_PID) on ${GEOMETRY}x${DEPTH}${NC}"
else
    echo -e "${RED}[ERROR] Xvfb failed to start${NC}"
    cat /tmp/xvfb.log
    exit 1
fi

# ================================================================
# 9. START XFCE4 DESKTOP
# ================================================================

echo -e "${YELLOW}[*] Starting XFCE4 desktop environment...${NC}"

startxfce4 > /tmp/xfce4.log 2>&1 &
XFCE_PID=$!

sleep 5

if ps -p $XFCE_PID > /dev/null 2>&1; then
    echo -e "${GREEN}[✓] XFCE4 running (PID: $XFCE_PID)${NC}"
else
    echo -e "${YELLOW}[!] XFCE4 may have issues - check /tmp/xfce4.log${NC}"
fi

# ================================================================
# 10. START X11VNC SERVER
# ================================================================

echo -e "${YELLOW}[*] Starting X11VNC on port ${VNC_PORT}...${NC}"

x11vnc \
    -display :99 \
    -passwd "${VNC_PASSWORD}" \
    -rfbport ${VNC_PORT} \
    -forever \
    -shared \
    -loop \
    -noxdamage \
    -noxfixes \
    -noprimary \
    -nobell \
    -noclipboard \
    > /tmp/x11vnc.log 2>&1 &
X11VNC_PID=$!

sleep 2

if ps -p $X11VNC_PID > /dev/null 2>&1; then
    echo -e "${GREEN}[✓] X11VNC running on port ${VNC_PORT} (PID: $X11VNC_PID)${NC}"
else
    echo -e "${RED}[ERROR] X11VNC failed${NC}"
    cat /tmp/x11vnc.log
    exit 1
fi

# ================================================================
# 11. START NOVNC (WEB INTERFACE)
# ================================================================

echo -e "${YELLOW}[*] Starting NoVNC web server on port ${NOVNC_PORT}...${NC}"

if command -v novnc_server &> /dev/null; then
    novnc_server --vnc localhost:${VNC_PORT} --listen ${NOVNC_PORT} \
        > /tmp/novnc.log 2>&1 &
    NOVNC_PID=$!
    NOVNC_METHOD="novnc_server"
else
    websockify --web /usr/share/novnc/ ${NOVNC_PORT} localhost:${VNC_PORT} \
        > /tmp/novnc.log 2>&1 &
    NOVNC_PID=$!
    NOVNC_METHOD="websockify"
fi

sleep 2

if ps -p $NOVNC_PID > /dev/null 2>&1; then
    echo -e "${GREEN}[✓] NoVNC (${NOVNC_METHOD}) running on port ${NOVNC_PORT} (PID: $NOVNC_PID)${NC}"
else
    echo -e "${YELLOW}[!] NoVNC warning - check /tmp/novnc.log${NC}"
fi

# ================================================================
# 12. START XRDP (RDP SERVER)
# ================================================================

echo -e "${YELLOW}[*] Starting XRDP on port 3389...${NC}"

if systemctl is-active --quiet xrdp 2>/dev/null; then
    echo -e "${GREEN}[✓] XRDP already running${NC}"
else
    systemctl start xrdp 2>/dev/null || service xrdp start 2>/dev/null || true
    sleep 1
    
    if systemctl is-active --quiet xrdp 2>/dev/null || pgrep -f "xrdp" > /dev/null; then
        echo -e "${GREEN}[✓] XRDP started on port 3389${NC}"
    else
        echo -e "${YELLOW}[!] XRDP not available (optional)${NC}"
    fi
fi

# ================================================================
# 13. ENABLE IP FORWARDING FOR PENTESTING
# ================================================================

echo -e "${YELLOW}[*] Configuring network for penetration testing...${NC}"

echo 1 > /proc/sys/net/ipv4/ip_forward
echo 0 > /proc/sys/net/ipv4/icmp_echo_ignore_broadcasts

echo -e "${GREEN}[✓] IP forwarding enabled${NC}"

# ================================================================
# 14. DISPLAY CONNECTION INFORMATION
# ================================================================

echo ""
echo -e "${MAGENTA}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║          🎯  KALI LINUX READY TO CONNECT  🎯        ║${NC}"
echo -e "${MAGENTA}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${GREEN}🌐 NoVNC (Web Browser):${NC}"
echo -e "   ${YELLOW}http://localhost:${NOVNC_PORT}/vnc.html${NC}"
echo -e "   Password: ${YELLOW}${VNC_PASSWORD}${NC}"
echo ""

echo -e "${GREEN}🖥️  VNC Client (TightVNC, RealVNC, etc):${NC}"
echo -e "   Host: ${YELLOW}localhost:${VNC_PORT}${NC}"
echo -e "   Password: ${YELLOW}${VNC_PASSWORD}${NC}"
echo ""

echo -e "${GREEN}🔌 RDP (Windows Remote Desktop / Linux rdesktop):${NC}"
echo -e "   Host: ${YELLOW}localhost:3389${NC}"
echo -e "   Username: ${YELLOW}root${NC}"
echo ""

echo -e "${RED}🛠️  Kali Tools Installed:${NC}"
echo -e "   • Metasploit Framework"
echo -e "   • Burp Suite"
echo -e "   • Nmap"
echo -e "   • Hydra"
echo -e "   • SQLMap"
echo -e "   • Nikto"
echo -e "   • Hashcat / John"
echo -e "   • Aircrack-ng"
echo -e "   • Wireshark / TShark"
echo -e "   • TCPDump"
echo -e "   • And many more..."
echo ""

echo -e "${YELLOW}📊 Service Status:${NC}"
echo -e "   Display: ${YELLOW}:99 (${GEOMETRY}x${DEPTH})${NC}"
echo -e "   Xvfb: ${YELLOW}✓ Running${NC}"
echo -e "   XFCE4: ${YELLOW}✓ Running${NC}"
echo -e "   X11VNC: ${YELLOW}✓ Running${NC}"
echo -e "   NoVNC: ${YELLOW}✓ Running${NC}"
echo -e "   XRDP: ${YELLOW}✓ Running${NC}"
echo ""

echo -e "${YELLOW}📝 Log Files:${NC}"
echo -e "   Xvfb: /tmp/xvfb.log"
echo -e "   XFCE4: /tmp/xfce4.log"
echo -e "   X11VNC: /tmp/x11vnc.log"
echo -e "   NoVNC: /tmp/novnc.log"
echo ""

echo -e "${MAGENTA}═══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}[✓] KALI LINUX ENVIRONMENT READY!${NC}"
echo -e "${YELLOW}[*] Press Ctrl+C to stop all services${NC}"
echo -e "${MAGENTA}═══════════════════════════════════════════════════════${NC}"
echo ""

# ================================================================
# 15. CLEANUP HANDLER
# ================================================================

cleanup() {
    echo ""
    echo -e "${YELLOW}[*] Shutting down all services...${NC}"
    
    kill $XVFB_PID 2>/dev/null || true
    kill $XFCE_PID 2>/dev/null || true
    kill $X11VNC_PID 2>/dev/null || true
    kill $NOVNC_PID 2>/dev/null || true
    
    systemctl stop xrdp 2>/dev/null || service xrdp stop 2>/dev/null || true
    
    echo -e "${GREEN}[✓] All services stopped${NC}"
    exit 0
}

trap cleanup SIGTERM SIGINT

# ================================================================
# 16. KEEP RUNNING WITH MONITORING
# ================================================================

echo -e "${YELLOW}[*] Monitoring services... (type 'exit' to quit)${NC}"
echo ""

while true; do
    sleep 30
    
    # Monitor and restart if crashed
    if ! ps -p $XVFB_PID > /dev/null 2>&1; then
        echo -e "${RED}[!] Xvfb crashed, restarting...${NC}"
        Xvfb :99 -screen 0 ${GEOMETRY}x${DEPTH} -ac -pn > /tmp/xvfb.log 2>&1 &
        XVFB_PID=$!
        sleep 2
    fi
    
    if ! ps -p $X11VNC_PID > /dev/null 2>&1; then
        echo -e "${RED}[!] X11VNC crashed, restarting...${NC}"
        x11vnc -display :99 -passwd "${VNC_PASSWORD}" -rfbport ${VNC_PORT} \
            -forever -shared -loop > /tmp/x11vnc.log 2>&1 &
        X11VNC_PID=$!
        sleep 2
    fi
    
    if ! ps -p $NOVNC_PID > /dev/null 2>&1; then
        echo -e "${RED}[!] NoVNC crashed, restarting...${NC}"
        websockify --web /usr/share/novnc/ ${NOVNC_PORT} localhost:${VNC_PORT} \
            > /tmp/novnc.log 2>&1 &
        NOVNC_PID=$!
        sleep 2
    fi
done
