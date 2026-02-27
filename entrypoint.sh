#!/bin/bash

# --- CHECK FOR ROOT ---
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)"
   exit 1
fi

echo "[*] Updating system repositories..."
apt update && apt upgrade -y

echo "[*] Installing XFCE4 and TightVNC Server..."
# kali-desktop-xfce is the optimized Kali version of XFCE
apt install -y kali-desktop-xfce xfce4 xfce4-goodies tightvncserver novnc websockify python3-numpy

# --- VNC CONFIGURATION ---
echo "[*] Setting up VNC password..."
# Set a default password 'kali' (Change this later with 'vncpasswd')
mkdir -p ~/.vnc
echo "kali123" | vncpasswd -f > ~/.vnc/passwd
chmod 600 ~/.vnc/passwd

# Create the VNC startup script to launch XFCE
cat <<EOF > ~/.vnc/xstartup
#!/bin/bash
xrdb \$HOME/.Xresources
startxfce4 &
EOF
chmod +x ~/.vnc/xstartup

# --- SERVICE MANAGEMENT (AUTORUN) ---
echo "[*] Creating startup script for the VNC + noVNC session..."

cat <<EOF > /usr/local/bin/start-kali-gui
#!/bin/bash
# Kill old sessions
vncserver -kill :1 > /dev/null 2>&1
rm -rf /tmp/.X1-lock /tmp/.X11-unix/X1

# Start VNC on port 5901
vncserver :1 -geometry 1280x720 -depth 24

# Start noVNC proxy on port 8006 (Redirects to VNC 5901)
/usr/share/novnc/utils/novnc_proxy --vnc localhost:5901 --listen 8006 &
EOF

chmod +x /usr/local/bin/start-kali-gui

# --- FINISHING UP ---
echo ""
echo "========================================================="
echo " INSTALLATION COMPLETE"
echo "========================================================="
echo "1. To start the GUI, run: sudo start-kali-gui"
echo "2. Access it in your browser at: http://YOUR_IP:8006/vnc.html"
echo "3. VNC Password is: kali123"
echo "========================================================="

# Auto-start now?
read -p "Do you want to start the GUI now? (y/n): " choice
if [[ $choice == "y" ]]; then
    /usr/local/bin/start-kali-gui
fi
