#!/bin/bash
# Startup script for Playwright service with Xvfb support
# This provides a virtual display for headed browser mode (required for Xero login)

# Kill any existing Xvfb processes
pkill -9 Xvfb 2>/dev/null || true

# Remove any stale lock files
rm -f /tmp/.X99-lock 2>/dev/null || true
rm -f /tmp/.X*-lock 2>/dev/null || true

# Start Xvfb (X Virtual Framebuffer) in the background
# -screen 0 1920x1080x24: 1920x1080 resolution with 24-bit color depth
# -ac: disable access control (allow any client to connect)
# +extension GLX: enable OpenGL extension for proper rendering
# +extension RANDR: enable resize/rotate extension
# +render: enable RENDER extension for font rendering
# -noreset: don't reset between client connections
# -dpi 96: set standard DPI for consistent font rendering
# -nolisten tcp: security - don't listen on TCP
# -fbdir /tmp: use /tmp for framebuffer (faster)
echo "Starting Xvfb virtual display..."
Xvfb :99 -screen 0 1920x1080x24 -ac +extension GLX +extension RANDR +render -noreset -dpi 96 -nolisten tcp -fbdir /tmp &
XVFB_PID=$!

# Wait for Xvfb to fully start and stabilize
echo "Waiting for Xvfb to initialize..."
sleep 3

# Set the DISPLAY environment variable to use the virtual display
export DISPLAY=:99

# Verify Xvfb is running with retries
MAX_RETRIES=5
RETRY_COUNT=0
XVFB_READY=false

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if pgrep -x "Xvfb" > /dev/null; then
        # Test the display is working
        if xdpyinfo -display :99 >/dev/null 2>&1; then
            echo "Display :99 is responsive and ready"
            XVFB_READY=true
            break
        else
            echo "Display :99 not ready yet, waiting..."
        fi
    else
        echo "Xvfb process not found, waiting..."
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    sleep 2
done

if [ "$XVFB_READY" = false ]; then
    echo "ERROR: Xvfb failed to start after $MAX_RETRIES attempts!"
    exit 1
fi

echo "Xvfb started successfully on display :99 (PID: $XVFB_PID)"

# Set additional environment variables for better rendering
export LIBGL_ALWAYS_SOFTWARE=1
export MESA_GL_VERSION_OVERRIDE=3.3

# Start the FastAPI application
echo "Starting Playwright service..."
exec python run.py
