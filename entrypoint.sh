#!/bin/bash

# Configure the password for x11vnc directly
PASSWORD="your_password_here"

# Start x11vnc with the provided password
x11vnc -forever -usepw -display :0 -rfbauth /path/to/vnc/passwd
