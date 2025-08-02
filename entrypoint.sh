#!/bin/bash
mkdir -p /usr/local/nginx/logs
touch /usr/local/nginx/logs/audit.log
ln -sf /usr/local/nginx/logs/audit.log /waf-logs/audit.log

# Start NGINX in background
/usr/local/nginx/sbin/nginx

# Start Flask
cd /webui
python3 bootstrap_users.py
python3 app.py
