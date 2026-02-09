#!/bin/bash
# Startup script for Playwright service with Xvfb support
# This provides a virtual display for headed browser mode (required for Xero login)

# Start Xvfb (X Virtual Framebuffer) in the background
# This creates a virtual display that allows headed browsers to run without a physical monitor
# Screen size is slightly larger than viewport (1920x1200) to provide headroom for window decorations
echo "Starting Xvfb virtual display..."
Xvfb :99 -screen 0 1920x1200x24 -ac +extension GLX +render -noreset &

# Wait for Xvfb to be ready (up to 10 seconds)
echo "Waiting for Xvfb to be ready..."
for i in $(seq 1 10); do
    if xdpyinfo -display :99 > /dev/null 2>&1; then
        echo "Xvfb is ready on display :99"
        break
    fi
    echo "Waiting for Xvfb... ($i/10)"
    sleep 1
done

# Set the DISPLAY environment variable to use the virtual display
export DISPLAY=:99

# Final verification
if pgrep -x "Xvfb" > /dev/null; then
    echo "Xvfb started successfully on display :99"
else
    echo "WARNING: Xvfb may not have started properly"
fi

# Start the FastAPI application
echo "Starting Playwright service..."
exec python run.py
