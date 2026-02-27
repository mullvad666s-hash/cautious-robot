#!/bin/bash
# entrypoint.sh - Kali Linux with noVNC on GitHub Codespaces (port 8006)
# No Docker needed - runs directly in Codespaces terminal

set -e

echo "============================================"
echo "  Kali Desktop + noVNC Setup for Codespaces"
echo "  Port: 8006"
echo "============================================"

# ── Update & Install Packages ──
sudo apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    kali-desktop-xfce \
    tigervnc-standalone-server \
    tigervnc-common \
    dbus-x11 \
    novnc \
    websockify \
    net-tools \
    xfonts-base \
    xfonts-100dpi \
    xfonts-75dpi \
    --no-install-recommends

# ── Cleanup ──
sudo apt-get clean
sudo rm -rf /var/lib/apt/lists/*

# ── Set VNC Password (default: "kali") ──
VNC_PASSWORD="${VNC_PASSWORD:-kali}"
mkdir -p ~/.vnc
echo "$VNC_PASSWORD" | vncpasswd -f > ~/.vnc/passwd
chmod 600 ~/.vnc/passwd

# ── VNC Startup Config ──
cat > ~/.vnc/xstartup <<'XSTARTUP'
#!/bin/bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
export XDG_SESSION_TYPE=x11
exec startxfce4 &
XSTARTUP
chmod +x ~/.vnc/xstartup

# ── Kill any existing sessions ──
vncserver -kill :1 2>/dev/null || true
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1 2>/dev/null || true

# ── Start VNC Server on display :1 (port 5901) ──
echo "[*] Starting VNC server on :1 ..."
vncserver :1 \
    -geometry 1920x1080 \
    -depth 24 \
    -localhost yes

# ── Find noVNC path ──
NOVNC_PATH=""
for p in /usr/share/novnc /usr/share/novnc/utils/../ /opt/novnc; do
    [ -d "$p" ] && NOVNC_PATH="$p" && break
done

if [ -z "$NOVNC_PATH" ]; then
    echo "[!] noVNC not found in standard paths, cloning from GitHub..."
    NOVNC_PATH="$HOME/noVNC"
    git clone --depth 1 https://github.com/novnc/noVNC.git "$NOVNC_PATH"
fi

# ── Symlink vnc.html → index.html for easy access ──
[ -f "$NOVNC_PATH/vnc.html" ] && \
    ln -sf "$NOVNC_PATH/vnc.html" "$NOVNC_PATH/index.html" 2>/dev/null || true

# ── Start websockify + noVNC on port 8006 ──
echo "[*] Starting noVNC on port 8006 ..."
websockify --web="$NOVNC_PATH" 8006 localhost:5901 &

# ── Wait & Print Access Info ──
sleep 3
echo ""
echo "============================================"
echo "  ✅ noVNC is running on port 8006"
echo ""
echo "  Open the Codespaces 'Ports' tab,"
echo "  find port 8006, and open in browser."
echo ""
echo "  VNC Password: $VNC_PASSWORD"
echo "============================================"
echo ""

# ── Keep alive ──
wait
