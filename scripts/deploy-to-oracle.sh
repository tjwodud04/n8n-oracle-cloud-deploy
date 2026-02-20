#!/bin/bash
set -e

# ===========================================
# n8n Oracle Cloud Deploy Script
# Run from local machine (Windows/WSL/Git Bash)
# ===========================================

# --- Configuration (edit these) ---
REMOTE_HOST="YOUR_SERVER_IP"
REMOTE_USER="opc"
SSH_KEY="$HOME/.ssh/your-ssh-key"
DOMAIN="your-subdomain.duckdns.org"
CERTBOT_EMAIL="your-email@example.com"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

SSH_CMD="ssh -i $SSH_KEY -o StrictHostKeyChecking=no $REMOTE_USER@$REMOTE_HOST"
SCP_CMD="scp -i $SSH_KEY -o StrictHostKeyChecking=no"

echo "========================================="
echo " n8n Oracle Cloud Deploy"
echo "========================================="
echo " Project: $PROJECT_DIR"
echo " Server:  $REMOTE_USER@$REMOTE_HOST"
echo " Domain:  $DOMAIN"
echo "========================================="
echo ""

# --- Step 1: SSH test ---
echo "=== Step 1: SSH connection test ==="
$SSH_CMD "echo 'SSH OK: $(hostname)'"
echo ""

# --- Step 2: Transfer files ---
echo "=== Step 2: File transfer ==="
$SCP_CMD "$PROJECT_DIR/oracle-setup.sh" "$REMOTE_USER@$REMOTE_HOST:/tmp/oracle-setup.sh"
$SCP_CMD "$PROJECT_DIR/docker-compose.cloud.yml" "$REMOTE_USER@$REMOTE_HOST:/tmp/docker-compose.yml"
$SCP_CMD "$PROJECT_DIR/.env.cloud" "$REMOTE_USER@$REMOTE_HOST:/tmp/.env"
$SCP_CMD "$PROJECT_DIR/scripts/nginx-n8n.conf" "$REMOTE_USER@$REMOTE_HOST:/tmp/n8n.conf"
$SCP_CMD "$PROJECT_DIR/scripts/duckdns-update.sh" "$REMOTE_USER@$REMOTE_HOST:/tmp/duckdns-update.sh"
echo "  Transfer complete"
echo ""

# --- Step 3: Run setup ---
echo "=== Step 3: Run oracle-setup.sh ==="
$SSH_CMD "chmod +x /tmp/oracle-setup.sh && sed -i 's/\r$//' /tmp/oracle-setup.sh && /tmp/oracle-setup.sh"
echo ""

# --- Step 4: n8n data migration ---
echo "=== Step 4: n8n data backup & transfer ==="
VOLUME_NAME=$(docker volume ls --format '{{.Name}}' | grep n8n_data | head -1)
if [ -z "$VOLUME_NAME" ]; then
  echo "  Warning: n8n_data volume not found"
  docker volume ls --format '{{.Name}}'
  echo "  Enter volume name:"
  read VOLUME_NAME
fi
echo "  Volume: $VOLUME_NAME"

docker run --rm \
  -v ${VOLUME_NAME}:/data \
  -v "$(pwd)":/backup \
  alpine tar czf /backup/n8n-backup.tar.gz -C /data .

$SCP_CMD "n8n-backup.tar.gz" "$REMOTE_USER@$REMOTE_HOST:/tmp/n8n-backup.tar.gz"
$SSH_CMD "sudo tar xzf /tmp/n8n-backup.tar.gz -C /opt/n8n/data/ && sudo chown -R 1000:1000 /opt/n8n/data/ && rm /tmp/n8n-backup.tar.gz"
rm -f n8n-backup.tar.gz
echo "  Data migration complete"
echo ""

# --- Step 5: Deploy files ---
echo "=== Step 5: Deploy files ==="
$SSH_CMD "
sudo mv /tmp/docker-compose.yml /opt/n8n/docker-compose.yml
sudo mv /tmp/.env /opt/n8n/.env
sudo mv /tmp/duckdns-update.sh /opt/n8n/duckdns-update.sh
sudo chmod +x /opt/n8n/duckdns-update.sh
sudo sed -i 's/\r$//' /opt/n8n/duckdns-update.sh
/opt/n8n/duckdns-update.sh
(crontab -l 2>/dev/null | grep -v 'duckdns-update'; echo '*/5 * * * * /opt/n8n/duckdns-update.sh > /dev/null 2>&1') | crontab -
sudo mv /tmp/n8n.conf /etc/nginx/conf.d/n8n.conf
sudo sed -i 's/YOUR_DOMAIN/$DOMAIN/g' /etc/nginx/conf.d/n8n.conf
rm -f /tmp/oracle-setup.sh
"
echo ""

# --- Step 6: Start n8n ---
echo "=== Step 6: Start n8n ==="
$SSH_CMD "cd /opt/n8n && sudo docker compose up -d"
echo "  Waiting 15s for startup..."
sleep 15
$SSH_CMD "docker ps --filter name=n8n --format 'ID: {{.ID}} / Status: {{.Status}}'"
echo ""

# --- Step 7: SSL certificate ---
echo "=== Step 7: SSL certificate ==="
$SSH_CMD "
# Temp HTTP-only config for certbot
sudo tee /etc/nginx/conf.d/n8n-temp.conf > /dev/null << 'EOF'
server {
    listen 80;
    server_name $DOMAIN;
    location /.well-known/acme-challenge/ { root /var/www/html; }
    location / { proxy_pass http://127.0.0.1:5678; }
}
EOF
sudo mv /etc/nginx/conf.d/n8n.conf /etc/nginx/conf.d/n8n-ssl.conf.bak
sudo nginx -t && sudo systemctl restart nginx

sudo certbot certonly --webroot -w /var/www/html \
  -d $DOMAIN --non-interactive --agree-tos \
  --email $CERTBOT_EMAIL --no-eff-email

sudo mv /etc/nginx/conf.d/n8n-ssl.conf.bak /etc/nginx/conf.d/n8n.conf
sudo rm -f /etc/nginx/conf.d/n8n-temp.conf
sudo nginx -t && sudo systemctl restart nginx
"
echo ""

# --- Step 8: Verify ---
echo "=== Step 8: Verify ==="
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "https://$DOMAIN" --max-time 10 2>/dev/null || echo "FAIL")
echo "  HTTPS: $HTTP_CODE"
$SSH_CMD "free -h"

echo ""
echo "========================================="
echo " Deploy complete!"
echo " Access: https://$DOMAIN"
echo "========================================="
