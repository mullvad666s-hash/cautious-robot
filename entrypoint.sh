#!/bin/bash

set -e

# ================================================================
# Kali Linux RDP + NoVNC Entrypoint Script
# For lightweight penetration testing environments
# ================================================================

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
VNC_PASSWORD="${VNC_PASSWORD:-kali123}"
VNC_PORT="${VNC_PORT:-5900}"
NOVNC_PORT="${NOVNC_PORT:-8080}"
RDP_PORT="${RDP_PORT:-3389}"
DISPLAY=":1"
GEOMETRY="${GEOMETRY:-1280x1024}"
DEPTH="${DEPTH:-24}"

echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  🔥  Kali Linux - RDP + NoVNC Server  🔥  ║${NC}"
echo -e "${GREEN}╚════════════════════════════════��═══════════╝${NC}"
echo ""

# ================================================================
# 1. System Setup
# ================================================================

echo -e "${YELLOW}[*] Setting up system environment...${NC}"

# Create necessary directories
mkdir -p /root/.vnc
mkdir -p /root/.config/xfce4
mkdir -p /run/dbus

# Start D-Bus daemon
if ! pgrep -x "dbus-daemon" > /dev/null; then
    echo -e "${YELLOW}[*] Starting D-Bus daemon...${NC}"
    dbus-daemon --system --nopidfile --nofork &
    sleep 1
fi

# ================================================================
# 2. VNC Password Setup
# ================================================================

echo -e "${YELLOW}[*] Configuring VNC password...${NC}"
echo "${VNC_PASSWORD}" | vncpasswd -f > /root/.vnc/passwd
chmod 600 /root/.vnc/passwd

# ================================================================
# 3. Start Xvfb (X Virtual Framebuffer)
# ================================================================

echo -e "${YELLOW}[*] Starting Xvfb...${NC}"
Xvfb ${DISPLAY} -screen 0 ${GEOMETRY}x${DEPTH} &
XVFB_PID=$!
sleep 2

# ================================================================
# 4. Start XFCE4 Desktop Environment
# ================================================================

echo -e "${YELLOW}[*] Starting XFCE4 desktop...${NC}"
export DISPLAY=${DISPLAY}
export XAUTHORITY=/root/.Xauthority
startxfce4 &
XFCE_PID=$!
sleep 3

# ================================================================
# 5. Start X11VNC Server
# ================================================================

echo -e "${YELLOW}[*] Starting X11VNC server on port ${VNC_PORT}...${NC}"
x11vnc \
    -display ${DISPLAY} \
    -rfbauth /root/.vnc/passwd \
    -rfbport ${VNC_PORT} \
    -forever \
    -shared \
    -loop \
    -noxdamage \
    -noxfixes &
X11VNC_PID=$!
sleep 2

# ================================================================
# 6. Start NoVNC (Web-based VNC)
# ================================================================

echo -e "${YELLOW}[*] Starting NoVNC on port ${NOVNC_PORT}...${NC}"

# Check if novnc_server exists, fallback to websockify
if command -v novnc_server &> /dev/null; then
    novnc_server --vnc localhost:${VNC_PORT} --listen ${NOVNC_PORT} &
    NOVNC_PID=$!
else
    # Use websockify as fallback
    websockify --web /usr/share/novnc/ ${NOVNC_PORT} localhost:${VNC_PORT} &
    NOVNC_PID=$!
fi

sleep 2

# ================================================================
# 7. Configure and Start XRDP (for RDP access)
# ================================================================

echo -e "${YELLOW}[*] Configuring XRDP for RDP access...${NC}"

# Create XRDP config if not exists
if [ ! -f /etc/xrdp/xrdp.ini ]; then
    mkdir -p /etc/xrdp
    cat > /etc/xrdp/xrdp.ini << 'XRDP_CONFIG'
[xrdp]
port=3389
use_vsock=false

[xrdp1]
name=Xvnc
lib=libvnc.so
ip=localhost
port=5900
username=
password=
XRDP_CONFIG
fi

# Start XRDP
if command -v xrdp &> /dev/null; then
    echo -e "${YELLOW}[*] Starting XRDP server on port ${RDP_PORT}...${NC}"
    /etc/init.d/xrdp start 2>/dev/null || xrdp -nodaemon &
    XRDP_PID=$!
    sleep 2
fi

# ================================================================
# 8. Security & Networking Setup
# ================================================================

echo -e "${YELLOW}[*] Configuring networking...${NC}"

# Enable IP forwarding (useful for penetration testing)
echo 1 > /proc/sys/net/ipv4/ip_forward

# Display network info
echo -e "${GREEN}[+] Network Configuration:${NC}"
hostname -I
echo ""

# ================================================================
# 9. Display Connection Information
# ================================================================

echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         Connection Information            ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}VNC Access:${NC}"
echo -e "  Port: ${VNC_PORT}"
echo -e "  Password: ${VNC_PASSWORD}"
echo -e "  Command: vncviewer localhost:${VNC_PORT}"
echo ""
echo -e "${YELLOW}NoVNC (Web Browser):${NC}"
echo -e "  URL: http://localhost:${NOVNC_PORT}/vnc.html"
echo -e "  Password: ${VNC_PASSWORD}"
echo ""
echo -e "${YELLOW}RDP Access:${NC}"
echo -e "  Host: localhost"
echo -e "  Port: ${RDP_PORT}"
echo -e "  Username: root"
echo ""
echo -e "${GREEN}[✓] All services started successfully!${NC}"
echo ""

# ================================================================
# 10. Signal Handlers & Container Management
# ================================================================

# Cleanup function
cleanup() {
    echo -e "${YELLOW}[*] Shutting down services...${NC}"
    kill $XVFB_PID 2>/dev/null || true
    kill $XFCE_PID 2>/dev/null || true
    kill $X11VNC_PID 2>/dev/null || true
    kill $NOVNC_PID 2>/dev/null || true
    kill $XRDP_PID 2>/dev/null || true
    exit 0
}

trap cleanup SIGTERM SIGINT

# Keep container running
wait