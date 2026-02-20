#!/bin/bash
set -e

# ===========================================
# Oracle Cloud n8n Setup Script
# OS: Oracle Linux 9 / Shape: VM.Standard.E2.1.Micro
# ===========================================

echo "========================================="
echo " Oracle Cloud n8n Setup"
echo "========================================="
echo ""

# --- 1. Swap (4GB) ---
echo "=== 1. Swap (4GB) ==="
if [ -f /swapfile ]; then
  SWAP_SIZE=$(swapon --show=SIZE --noheadings 2>/dev/null | head -1)
  echo "Existing swap: $SWAP_SIZE — recreating as 4GB..."
  sudo swapoff /swapfile 2>/dev/null || true
  sudo rm -f /swapfile
fi
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
if ! grep -q '/swapfile' /etc/fstab; then
  echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
fi
sudo sysctl vm.swappiness=10
echo 'vm.swappiness=10' | sudo tee /etc/sysctl.d/99-swappiness.conf
echo "Swap done"
free -h
echo ""

# --- 2. System update ---
echo "=== 2. System update ==="
sudo dnf update -y
echo ""

# --- 3. Docker CE ---
echo "=== 3. Docker ==="
if ! command -v docker &> /dev/null; then
  sudo dnf install -y dnf-utils
  sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
  sudo dnf remove -y runc containerd.io 2>/dev/null || true
  sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
  sudo systemctl enable --now docker
  sudo usermod -aG docker opc
  echo "Docker installed (re-login to apply group)"
else
  echo "Docker already installed"
fi
docker --version
docker compose version
echo ""

# --- 4. Firewall ---
echo "=== 4. Firewall ==="
if systemctl is-active --quiet firewalld; then
  sudo firewall-cmd --permanent --zone=public --add-port=5678/tcp
  sudo firewall-cmd --permanent --zone=public --add-port=80/tcp
  sudo firewall-cmd --permanent --zone=public --add-port=443/tcp
  sudo firewall-cmd --reload
  echo "firewalld ports opened:"
  sudo firewall-cmd --permanent --zone=public --list-ports
else
  echo "firewalld inactive — using iptables"
  sudo iptables -I INPUT -p tcp --dport 5678 -j ACCEPT
  sudo iptables -I INPUT -p tcp --dport 80 -j ACCEPT
  sudo iptables -I INPUT -p tcp --dport 443 -j ACCEPT
  sudo dnf install -y iptables-services 2>/dev/null || true
  sudo service iptables save 2>/dev/null || true
fi

# SELinux: allow Nginx to proxy
sudo setsebool -P httpd_can_network_connect 1 2>/dev/null || true
echo ""

# --- 5. n8n data directory ---
echo "=== 5. n8n data directory ==="
sudo mkdir -p /opt/n8n/data
sudo chown -R 1000:1000 /opt/n8n
echo "/opt/n8n/data created"
echo ""

# --- 6. Nginx ---
echo "=== 6. Nginx ==="
if ! command -v nginx &> /dev/null; then
  sudo dnf install -y nginx
  sudo systemctl enable nginx
  echo "Nginx installed"
else
  echo "Nginx already installed"
fi
echo ""

# --- 7. Certbot ---
echo "=== 7. Certbot ==="
if ! command -v certbot &> /dev/null; then
  sudo dnf install -y epel-release 2>/dev/null || true
  sudo dnf install -y --enablerepo=ol9_developer_EPEL certbot python3-certbot-nginx 2>/dev/null \
    || sudo dnf install -y certbot python3-certbot-nginx
  echo "Certbot installed"
else
  echo "Certbot already installed"
fi
echo ""

# --- 8. Certbot auto-renewal cron ---
echo "=== 8. Certbot auto-renewal cron ==="
(crontab -l 2>/dev/null | grep -v 'certbot'; echo "0 3 * * * certbot renew --quiet --post-hook 'systemctl reload nginx'") | crontab -
echo "Certbot renewal cron registered (daily 03:00)"
echo ""

# --- 9. Webroot SELinux context ---
echo "=== 9. Webroot ==="
sudo mkdir -p /var/www/html
sudo chcon -R -t httpd_sys_content_t /var/www/html/ 2>/dev/null || true
echo ""

echo "========================================="
echo " Setup complete!"
echo " Next: docker compose up -d"
echo "========================================="
