#!/bin/bash
# ===========================================
# SSL Setup for Cloudflare Grey Cloud (DNS Only)
# ===========================================
# This script sets up Nginx + Let's Encrypt SSL for direct HTTPS access
# Run as root on your DigitalOcean droplet

set -e

# Configuration - CHANGE THESE
DOMAIN="xero-automation.dext.com.au"
EMAIL="your-email@example.com"  # For Let's Encrypt notifications

echo "=== SSL Setup for Grey Cloud ==="
echo "Domain: $DOMAIN"
echo ""

# Step 1: Install Nginx and Certbot
echo "Installing Nginx and Certbot..."
apt update
apt install -y nginx certbot python3-certbot-nginx

# Step 2: Configure firewall
echo "Configuring firewall..."
ufw allow 'Nginx Full'
ufw allow 443/tcp
ufw allow 80/tcp  # Needed for Let's Encrypt verification
ufw reload

# Step 3: Create Nginx config for the domain
echo "Creating Nginx configuration..."
cat > /etc/nginx/sites-available/$DOMAIN << 'NGINX_CONF'
server {
    listen 80;
    server_name DOMAIN_PLACEHOLDER;
    
    # Redirect HTTP to HTTPS
    location / {
        return 301 https://$host$request_uri;
    }
    
    # Let's Encrypt verification
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
}

server {
    listen 443 ssl http2;
    server_name DOMAIN_PLACEHOLDER;
    
    # SSL certificates (will be configured by certbot)
    # ssl_certificate /etc/letsencrypt/live/DOMAIN_PLACEHOLDER/fullchain.pem;
    # ssl_certificate_key /etc/letsencrypt/live/DOMAIN_PLACEHOLDER/privkey.pem;
    
    # SSL settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    
    # Proxy settings for long-running requests (like automated login)
    proxy_connect_timeout 300s;
    proxy_send_timeout 300s;
    proxy_read_timeout 300s;
    
    # Proxy to the Docker container
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        
        # Increase buffer sizes for large responses
        proxy_buffer_size 128k;
        proxy_buffers 4 256k;
        proxy_busy_buffers_size 256k;
    }
}
NGINX_CONF

# Replace placeholder with actual domain
sed -i "s/DOMAIN_PLACEHOLDER/$DOMAIN/g" /etc/nginx/sites-available/$DOMAIN

# Enable the site
ln -sf /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test Nginx config
nginx -t

# Reload Nginx (without SSL first for Let's Encrypt verification)
systemctl reload nginx

# Step 4: Get Let's Encrypt certificate
echo ""
echo "Getting Let's Encrypt SSL certificate..."
echo "Make sure your DNS is pointing to this server (grey cloud in Cloudflare)!"
echo ""

certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m $EMAIL

# Step 5: Set up auto-renewal
echo "Setting up auto-renewal..."
systemctl enable certbot.timer
systemctl start certbot.timer

# Step 6: Reload Nginx with SSL
systemctl reload nginx

echo ""
echo "=== SSL Setup Complete ==="
echo ""
echo "Your API is now available at: https://$DOMAIN"
echo ""
echo "Test with:"
echo "  curl https://$DOMAIN/api/health"
echo ""
echo "Important: The Nginx config has 300s timeout for long-running requests"
echo "This allows the automated login to complete without timing out."
