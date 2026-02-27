#!/bin/bash
#=============================================
# entrypoint.sh
# Kali Linux XFCE Desktop + noVNC
# GitHub Codespaces - Port 8006
#=============================================

set -e

# ── Configuration ──
VNC_PORT=5901
NOVNC_PORT=8006
VNC_DISPLAY=":1"
VNC_RESOLUTION="1920x1080"
VNC_DEPTH="24"
VNC_PASSWORD="${VNC_PASSWORD:-kali123}"
NOVNC_DIR="$HOME/noVNC"
WEBSOCKIFY_DIR="$HOME/websockify"
LOG_DIR="$HOME/.logs"

# ── Colors ──
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# ── Functions ──
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${CYAN}[STEP]${NC} $1"
}

cleanup_previous() {
    log_step "Cleaning up previous sessions..."

    vncserver -kill "$VNC_DISPLAY" 2>/dev/null || true
    pkill -f websockify 2>/dev/null || true
    pkill -f "novnc" 2>/dev/null || true
    pkill -f Xtigervnc 2>/dev/null || true
    pkill -f Xvnc 2>/dev/null || true

    rm -f /tmp/.X1-lock 2>/dev/null || true
    rm -f /tmp/.X11-unix/X1 2>/dev/null || true
    rm -rf /tmp/.ICE-unix 2>/dev/null || true
    rm -rf /tmp/.dbus 2>/dev/null || true

    sleep 2
    log_info "Cleanup done."
}

create_dirs() {
    log_step "Creating directories..."
    mkdir -p "$LOG_DIR"
    mkdir -p "$HOME/.vnc"
    mkdir -p "$HOME/.config"
    log_info "Directories created."
}

add_kali_repo() {
    log_step "Adding Kali Linux repository..."

    if ! grep -q "kali-rolling" /etc/apt/sources.list 2>/dev/null && \
       ! ls /etc/apt/sources.list.d/kali* 2>/dev/null; then

        sudo sh -c 'echo "deb http://http.kali.org/kali kali-rolling main contrib non-free non-free-firmware" > /etc/apt/sources.list.d/kali.list'

        wget -q -O - https://archive.kali.org/archive-key.asc | sudo apt-key add - 2>/dev/null || \
        wget -q -O /tmp/kali-key.asc https://archive.kali.org/archive-key.asc && \
        sudo gpg --dearmor -o /usr/share/keyrings/kali-archive-keyring.gpg /tmp/kali-key.asc 2>/dev/null && \
        sudo sed -i 's|^deb |deb [signed-by=/usr/share/keyrings/kali-archive-keyring.gpg] |' /etc/apt/sources.list.d/kali.list 2>/dev/null || true

        log_info "Kali repository added."
    else
        log_info "Kali repository already present."
    fi
}

install_packages() {
    log_step "Updating package lists..."
    sudo apt-get update -y 2>&1 | tail -5

    log_step "Installing core dependencies..."
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
        wget \
        curl \
        git \
        net-tools \
        procps \
        x11-utils \
        x11-xserver-utils \
        xfonts-base \
        xfonts-100dpi \
        xfonts-75dpi \
        xfonts-scalable \
        xauth \
        dbus \
        dbus-x11 \
        2>&1 | tail -5

    log_info "Core dependencies installed."

    log_step "Installing XFCE desktop environment..."
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
        xfce4 \
        xfce4-terminal \
        xfce4-whiskermenu-plugin \
        xfce4-taskmanager \
        thunar \
        mousepad \
        2>&1 | tail -5

    log_info "XFCE desktop installed."

    log_step "Installing VNC server..."
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
        tigervnc-standalone-server \
        tigervnc-common \
        tigervnc-tools \
        2>&1 | tail -5

    log_info "VNC server installed."

    log_step "Installing Python3 + numpy for websockify..."
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
        python3 \
        python3-numpy \
        python3-pip \
        2>&1 | tail -5

    log_info "Python3 installed."

    log_step "Installing extra tools..."
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
        firefox-esr \
        nano \
        htop \
        2>&1 | tail -5 || log_warn "Some extra tools may not have installed."

    log_info "Package installation complete."
}

setup_novnc() {
    log_step "Setting up noVNC..."

    if [ -d "$NOVNC_DIR" ]; then
        log_info "noVNC directory exists, pulling latest..."
        cd "$NOVNC_DIR" && git pull 2>/dev/null || true
    else
        log_info "Cloning noVNC..."
        git clone --depth 1 https://github.com/novnc/noVNC.git "$NOVNC_DIR"
    fi

    if [ -d "$WEBSOCKIFY_DIR" ]; then
        log_info "websockify directory exists, pulling latest..."
        cd "$WEBSOCKIFY_DIR" && git pull 2>/dev/null || true
    else
        log_info "Cloning websockify..."
        git clone --depth 1 https://github.com/novnc/websockify.git "$WEBSOCKIFY_DIR"
    fi

    ln -sf "$WEBSOCKIFY_DIR" "$NOVNC_DIR/utils/websockify" 2>/dev/null || true

    if [ -f "$NOVNC_DIR/vnc.html" ]; then
        cp -f "$NOVNC_DIR/vnc.html" "$NOVNC_DIR/index.html"
        log_info "index.html symlinked."
    elif [ -f "$NOVNC_DIR/vnc_lite.html" ]; then
        cp -f "$NOVNC_DIR/vnc_lite.html" "$NOVNC_DIR/index.html"
        log_info "index.html from vnc_lite."
    fi

    log_info "noVNC setup complete."
}

configure_vnc() {
    log_step "Configuring VNC server..."

    echo "$VNC_PASSWORD" | vncpasswd -f > "$HOME/.vnc/passwd"
    chmod 600 "$HOME/.vnc/passwd"
    log_info "VNC password set."

    cat > "$HOME/.vnc/xstartup" << 'VNCSTARTUP'
#!/bin/bash

# Clean environment
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS

# Set environment variables
export XDG_SESSION_TYPE=x11
export XDG_RUNTIME_DIR="/tmp/runtime-$(whoami)"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.local/share"
export DISPLAY=:1

# Create runtime dir
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

# Start dbus
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
    eval $(dbus-launch --sh-syntax --exit-with-session)
    export DBUS_SESSION_BUS_ADDRESS
fi

# Set background color
xsetroot -solid "#1a1a2e" 2>/dev/null || true

# Disable screen saver and power management
xset s off 2>/dev/null || true
xset -dpms 2>/dev/null || true
xset s noblank 2>/dev/null || true

# Start XFCE
exec startxfce4 &

wait
VNCSTARTUP

    chmod +x "$HOME/.vnc/xstartup"
    log_info "VNC xstartup configured."

    cat > "$HOME/.vnc/config" << VNCCONFIG
geometry=$VNC_RESOLUTION
depth=$VNC_DEPTH
localhost=yes
SecurityTypes=VncAuth
VNCCONFIG

    log_info "VNC config written."
}

start_vnc() {
    log_step "Starting VNC server on display $VNC_DISPLAY..."

    export USER=$(whoami)

    vncserver "$VNC_DISPLAY" \
        -geometry "$VNC_RESOLUTION" \
        -depth "$VNC_DEPTH" \
        -localhost yes \
        -SecurityTypes VncAuth \
        -xstartup "$HOME/.vnc/xstartup" \
        2>&1 | tee "$LOG_DIR/vnc.log"

    sleep 3

    if pgrep -f "Xtigervnc.*$VNC_DISPLAY" > /dev/null 2>&1 || \
       pgrep -f "Xvnc.*$VNC_DISPLAY" > /dev/null 2>&1; then
        log_info "VNC server started successfully on port $VNC_PORT."
    else
        log_error "VNC server failed to start!"
        log_error "Log output:"
        cat "$LOG_DIR/vnc.log" 2>/dev/null
        log_warn "Retrying with basic settings..."

        vncserver "$VNC_DISPLAY" \
            -geometry "1280x720" \
            -depth 16 \
            -localhost yes \
            2>&1 | tee "$LOG_DIR/vnc_retry.log"

        sleep 3

        if pgrep -f "Xtigervnc\|Xvnc" > /dev/null 2>&1; then
            log_info "VNC server started on retry."
        else
            log_error "VNC server failed on retry. Exiting."
            cat "$LOG_DIR/vnc_retry.log"
            exit 1
        fi
    fi
}

start_novnc() {
    log_step "Starting noVNC on port $NOVNC_PORT..."

    cd "$NOVNC_DIR"

    python3 "$WEBSOCKIFY_DIR/websockify.py" \
        --web "$NOVNC_DIR" \
        --heartbeat 30 \
        "$NOVNC_PORT" \
        "localhost:$VNC_PORT" \
        > "$LOG_DIR/novnc.log" 2>&1 &

    NOVNC_PID=$!
    echo "$NOVNC_PID" > "$LOG_DIR/novnc.pid"

    sleep 3

    if kill -0 "$NOVNC_PID" 2>/dev/null; then
        log_info "noVNC started successfully on port $NOVNC_PORT (PID: $NOVNC_PID)."
    else
        log_error "noVNC websockify failed to start!"
        cat "$LOG_DIR/novnc.log"
        log_warn "Trying alternative launch..."

        "$WEBSOCKIFY_DIR/run" \
            --web "$NOVNC_DIR" \
            "$NOVNC_PORT" \
            "localhost:$VNC_PORT" \
            > "$LOG_DIR/novnc2.log" 2>&1 &

        NOVNC_PID=$!
        sleep 3

        if kill -0 "$NOVNC_PID" 2>/dev/null; then
            log_info "noVNC started on alternative method (PID: $NOVNC_PID)."
        else
            log_error "noVNC failed. Check logs."
            cat "$LOG_DIR/novnc2.log"
            exit 1
        fi
    fi
}

verify_services() {
    log_step "Verifying all services..."

    local all_ok=true

    if pgrep -f "Xtigervnc\|Xvnc" > /dev/null 2>&1; then
        log_info "✅ VNC server is running."
    else
        log_error "❌ VNC server is NOT running."
        all_ok=false
    fi

    if pgrep -f "websockify" > /dev/null 2>&1; then
        log_info "✅ noVNC/websockify is running."
    else
        log_error "❌ noVNC/websockify is NOT running."
        all_ok=false
    fi

    if netstat -tlnp 2>/dev/null | grep -q ":$NOVNC_PORT" || \
       ss -tlnp 2>/dev/null | grep -q ":$NOVNC_PORT"; then
        log_info "✅ Port $NOVNC_PORT is listening."
    else
        log_warn "⚠️  Port $NOVNC_PORT not detected yet (may take a moment)."
    fi

    if [ "$all_ok" = true ]; then
        return 0
    else
        return 1
    fi
}

print_banner() {
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                                                   ║${NC}"
    echo -e "${CYAN}║   ${GREEN}🐉 Kali Linux XFCE Desktop - Ready!${CYAN}             ║${NC}"
    echo -e "${CYAN}║                                                   ║${NC}"
    echo -e "${CYAN}║   ${NC}noVNC Port  : ${YELLOW}$NOVNC_PORT${CYAN}                          ║${NC}"
    echo -e "${CYAN}║   ${NC}VNC Port    : ${YELLOW}$VNC_PORT (internal)${CYAN}               ║${NC}"
    echo -e "${CYAN}║   ${NC}Resolution  : ${YELLOW}$VNC_RESOLUTION${CYAN}                      ║${NC}"
    echo -e "${CYAN}║   ${NC}Password    : ${YELLOW}$VNC_PASSWORD${CYAN}                        ║${NC}"
    echo -e "${CYAN}║                                                   ║${NC}"
    echo -e "${CYAN}║   ${GREEN}HOW TO CONNECT:${CYAN}                                 ║${NC}"
    echo -e "${CYAN}║   ${NC}1. Go to the PORTS tab in Codespaces${CYAN}            ║${NC}"
    echo -e "${CYAN}║   ${NC}2. Find port $NOVNC_PORT${CYAN}                              ║${NC}"
    echo -e "${CYAN}║   ${NC}3. Set visibility to Public${CYAN}                     ║${NC}"
    echo -e "${CYAN}║   ${NC}4. Click the globe icon to open in browser${CYAN}      ║${NC}"
    echo -e "${CYAN}║   ${NC}5. Enter password: ${YELLOW}$VNC_PASSWORD${CYAN}                   ║${NC}"
    echo -e "${CYAN}║                                                   ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════╝${NC}"
    echo ""
}

keep_alive() {
    log_info "Keeping session alive. Press Ctrl+C to stop."
    echo ""

    while true; do
        if ! pgrep -f "Xtigervnc\|Xvnc" > /dev/null 2>&1; then
            log_warn "VNC server died. Restarting..."
            cleanup_previous
            start_vnc
            start_novnc
            log_info "Services restarted."
        fi

        if ! pgrep -f "websockify" > /dev/null 2>&1; then
            log_warn "noVNC died. Restarting..."
            start_novnc
            log_info "noVNC restarted."
        fi

        sleep 10
    done
}

# ── Trap for cleanup on exit ──
trap_cleanup() {
    echo ""
    log_warn "Shutting down..."
    vncserver -kill "$VNC_DISPLAY" 2>/dev/null || true
    pkill -f websockify 2>/dev/null || true
    log_info "All services stopped. Bye!"
    exit 0
}

trap trap_cleanup SIGINT SIGTERM EXIT

# ═══════════════════════════════════════════
#              MAIN EXECUTION
# ═══════════════════════════════════════════

echo ""
echo -e "${CYAN}═══════════════════════════════════════════${NC}"
echo -e "${CYAN}  Kali XFCE + noVNC Installer${NC}"
echo -e "${CYAN}  GitHub Codespaces Edition${NC}"
echo -e "${CYAN}═══════════════════════════════════════════${NC}"
echo ""

create_dirs
cleanup_previous
add_kali_repo
install_packages
setup_novnc
configure_vnc
start_vnc
start_novnc

if verify_services; then
    print_banner
else
    log_error "Some services failed. Check logs in $LOG_DIR/"
    log_warn "Attempting to continue anyway..."
    print_banner
fi

keep_alive
