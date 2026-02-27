FROM kalilinux/kali:latest

LABEL maintainer="Kali Linux" \
      description="Kali Linux with RDP, VNC, and NoVNC for penetration testing"

# Install minimal desktop environment + remote access tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Desktop Environment (XFCE4 - lightweight)
    xfce4 \
    xfce4-terminal \
    xfce4-taskmanager \
    \
    # X Server
    xvfb \
    x11-apps \
    dbus \
    \
    # VNC & NoVNC
    x11vnc \
    novnc \
    websockify \
    \
    # RDP Server
    xrdp \
    \
    # Kali Tools (essential only)
    nmap \
    netcat-openbsd \
    curl \
    wget \
    git \
    vim \
    net-tools \
    iputils-ping \
    openssh-client \
    \
    # System utilities
    supervisor \
    dbus-x11 \
    \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Create VNC directory
RUN mkdir -p /root/.vnc

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expose ports
EXPOSE 5900 8080 3389

# Set environment variables
ENV DISPLAY=:1 \
    VNC_PASSWORD=kali123 \
    VNC_PORT=5900 \
    NOVNC_PORT=8080 \
    RDP_PORT=3389

ENTRYPOINT ["/entrypoint.sh"]
CMD ["tail", "-f", "/dev/null"]