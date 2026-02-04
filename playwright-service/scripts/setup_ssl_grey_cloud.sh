#!/bin/bash
# ===========================================
# SSL Setup for Cloudflare Grey Cloud (DNS Only)
# ===========================================
# This script sets up Nginx + Let's Encrypt SSL for direct HTTPS access
# Run as root on your DigitalOcean droplet
#
# IMPORTANT: This script bootstraps in 2 stages:
# 1. HTTP-only config (so Nginx can start and Certbot can verify)
# 2. Full HTTPS config (after certificates are obtained)

set -e

# Configuration - CHANGE THESE
DOMAIN="xero-automation.dext.com.au"
EMAIL="your-email@example.com"  # For Let's Encrypt notifications

echo "=== SSL Setup for Grey Cloud ==="
echo "Domain: $DOMAIN"
echo ""

# Step 1: Install Nginx and Certbot
echo "Step 1: Installing Nginx and Certbot..."
apt update
apt install -y nginx certbot python3-certbot-nginx

# Step 2: Configure firewall
echo "Step 2: Configuring firewall..."
ufw allow 'Nginx Full'
ufw allow 443/tcp
ufw allow 80/tcp
ufw reload

# Step 3: Create HTTP-only Nginx config first (so Certbot can verify domain)
echo "Step 3: Creating initial HTTP-only configuration..."
cat > /etc/nginx/sites-available/$DOMAIN << 'NGINX_HTTP'
server {
    listen 80;
    listen [::]:80;
    server_name DOMAIN_PLACEHOLDER;
    
    # Certbot verification
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }

    # Temporary: proxy to app (will redirect to HTTPS after cert is obtained)
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
NGINX_HTTP

sed -i "s/DOMAIN_PLACEHOLDER/$DOMAIN/g" /etc/nginx/sites-available/$DOMAIN

ln -sf /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

echo "Testing and reloading Nginx (HTTP-only)..."
nginx -t
systemctl reload nginx

# Step 4: Get Let's Encrypt certificate
echo ""
echo "Step 4: Getting Let's Encrypt SSL certificate..."
certbot certonly --webroot -w /var/www/html -d $DOMAIN --non-interactive --agree-tos -m $EMAIL

# Step 5: Create final HTTPS Nginx config
echo "Step 5: Creating final HTTPS configuration..."
cat > /etc/nginx/sites-available/$DOMAIN << 'NGINX_SSL'
server {
    listen 80;
    listen [::]:80;
    server_name DOMAIN_PLACEHOLDER;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name DOMAIN_PLACEHOLDER;
    
    # SSL certificates
    ssl_certificate /etc/letsencrypt/live/DOMAIN_PLACEHOLDER/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/DOMAIN_PLACEHOLDER/privkey.pem;
    
    # SSL settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    
    # Proxy timeouts for long-running requests
    proxy_connect_timeout 300s;
    proxy_send_timeout 300s;
    proxy_read_timeout 300s;
    
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
        
        proxy_buffer_size 128k;
        proxy_buffers 4 256k;
        proxy_busy_buffers_size 256k;
    }
}
NGINX_SSL

sed -i "s/DOMAIN_PLACEHOLDER/$DOMAIN/g" /etc/nginx/sites-available/$DOMAIN

echo "Testing and reloading Nginx (HTTPS)..."
nginx -t
systemctl reload nginx

# Step 6: Set up auto-renewal
echo "Step 6: Setting up auto-renewal..."
systemctl enable certbot.timer
systemctl start certbot.timer

echo ""
echo "=== SSL Setup Complete ==="
echo "Your API is now available at: https://$DOMAIN"
echo ""
echo "Test with: curl https://$DOMAIN/api/health"
