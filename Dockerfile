# Use Ubuntu as the base image
FROM ubuntu:20.04

# Set environment variables for non-interactive installation
ENV DEBIAN_FRONTEND=noninteractive

# Install necessary packages for RDP and NoVNC
RUN apt-get update \
    && apt-get install -y \
       xrdp \
       novnc \
       websockify \
       xfce4 \
       xfce4-goodies \
       && apt-get clean \
       && rm -rf /var/lib/apt/lists/*

# Set up XRDP
RUN echo "xfce4-session" >~/.xsession

# Expose the RDP and NoVNC ports
EXPOSE 3389 6080

# Start XRDP and NoVNC server
CMD ["/bin/bash", "-c", "service xrdp start && websockify --web=/usr/share/novnc 6080 localhost:3389"]