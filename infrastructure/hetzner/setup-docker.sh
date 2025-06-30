#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
DOMAIN="aigentics-germany.de"
MAIL_DOMAIN="mail.${DOMAIN}"
EMAIL="patrick.schoenfeld@${DOMAIN}"
FORWARD_EMAIL="aigentics.germany@gmail.com"

echo -e "${GREEN}Starting AIGentics Germany Server Setup${NC}"
echo "========================================"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root${NC}" 
   exit 1
fi

# Get server IP
SERVER_IP=$(curl -s ifconfig.me)
echo -e "${GREEN}Server IP: ${SERVER_IP}${NC}"

# Create directory structure
echo -e "${YELLOW}Creating directory structure...${NC}"
cd /opt/docker
mkdir -p {traefik,poste,nginx}/{data,config}
mkdir -p nginx/html

# Download configuration files
echo -e "${YELLOW}Downloading configuration files...${NC}"
REPO_URL="https://raw.githubusercontent.com/patrickjaja/aigentics-germany/main/infrastructure/hetzner"

# Download docker-compose.yml
curl -o docker-compose.yml "${REPO_URL}/docker-compose.yml" || {
    echo -e "${RED}Failed to download docker-compose.yml${NC}"
    exit 1
}

# Download Traefik configuration
curl -o traefik/traefik.yml "${REPO_URL}/traefik/traefik.yml" || {
    echo -e "${RED}Failed to download traefik.yml${NC}"
    exit 1
}

# Download nginx configuration
curl -o nginx/nginx.conf "${REPO_URL}/nginx/nginx.conf" || {
    echo -e "${RED}Failed to download nginx.conf${NC}"
    exit 1
}

# Download index.html
curl -o nginx/html/index.html "${REPO_URL}/nginx/html/index.html" || {
    echo -e "${RED}Failed to download index.html${NC}"
    exit 1
}

# Create acme.json with correct permissions
touch traefik/acme.json
chmod 600 traefik/acme.json

# Generate password for Traefik dashboard
echo -e "${YELLOW}Generating Traefik dashboard password...${NC}"
TRAEFIK_PASSWORD=$(openssl rand -base64 12)
TRAEFIK_HASH=$(docker run --rm httpd:2.4-alpine htpasswd -nbB admin "${TRAEFIK_PASSWORD}" | sed -e s/\\$/\\$\\$/g)

# Update docker-compose.yml with the generated hash
sed -i "s|admin:\\\$\\\$2y\\\$\\\$10\\\$\\\$jBmFX5EXAMPLE|${TRAEFIK_HASH}|g" docker-compose.yml

# Set up hostname
echo -e "${YELLOW}Setting up hostname...${NC}"
hostnamectl set-hostname ${MAIL_DOMAIN}
echo "${SERVER_IP} ${MAIL_DOMAIN} ${DOMAIN}" >> /etc/hosts

# Start Docker services
echo -e "${YELLOW}Starting Docker services...${NC}"
docker compose up -d

# Wait for services to start
echo -e "${YELLOW}Waiting for services to start...${NC}"
sleep 30

# Configure Poste.io
echo -e "${YELLOW}Configuring Poste.io mail server...${NC}"
echo -e "${GREEN}Please complete the following steps:${NC}"
echo ""
echo "1. Open your browser and go to: https://${MAIL_DOMAIN}"
echo "2. Complete the Poste.io setup wizard:"
echo "   - Admin email: ${EMAIL}"
echo "   - Choose a strong password for the admin account"
echo ""
echo "3. After setup, configure email forwarding:"
echo "   - Log in to Poste.io admin panel"
echo "   - Go to 'Virtual Domains' → '${DOMAIN}'"
echo "   - Click on 'Mailboxes' → 'patrick.schoenfeld'"
echo "   - Set up forwarding to: ${FORWARD_EMAIL}"
echo ""
echo "4. Configure your email client:"
echo "   - SMTP Server: ${MAIL_DOMAIN}"
echo "   - Port: 587 (STARTTLS)"
echo "   - Username: ${EMAIL}"
echo "   - Password: [the password you set]"
echo ""
echo -e "${GREEN}Credentials saved to /root/server-credentials.txt${NC}"

# Save credentials
cat > /root/server-credentials.txt << EOF
AIGentics Germany Server Credentials
====================================

Server IP: ${SERVER_IP}
Domain: ${DOMAIN}
Mail Domain: ${MAIL_DOMAIN}

Traefik Dashboard:
- URL: https://traefik.${DOMAIN}
- Username: admin
- Password: ${TRAEFIK_PASSWORD}

Email Configuration:
- Admin Email: ${EMAIL}
- Forward to: ${FORWARD_EMAIL}
- SMTP Server: ${MAIL_DOMAIN}:587
- IMAP Server: ${MAIL_DOMAIN}:993

Poste.io Admin:
- URL: https://${MAIL_DOMAIN}
- Username: ${EMAIL}
- Password: [Set during setup]

DNS Records to configure:
-------------------------
Type  Name                 Value
A     @                    ${SERVER_IP}
A     mail                 ${SERVER_IP}
A     traefik              ${SERVER_IP}
MX    @          10        ${MAIL_DOMAIN}
TXT   @                    "v=spf1 ip4:${SERVER_IP} ~all"
TXT   _dmarc               "v=DMARC1; p=none; rua=mailto:postmaster@${DOMAIN}"
EOF

chmod 600 /root/server-credentials.txt

# Create DNS configuration script
cat > /root/configure-dns.sh << 'EOF'
#!/bin/bash
# After configuring DNS and Poste.io, run this script to set up DKIM

DOMAIN="aigentics-germany.de"
SELECTOR="mail"

# Get DKIM key from Poste.io
echo "Fetching DKIM key from Poste.io..."
docker exec -it poste cat /data/domains/${DOMAIN}/dkim/${SELECTOR}.txt 2>/dev/null || {
    echo "DKIM key not found. Please ensure Poste.io is configured first."
    exit 1
}

echo ""
echo "Add this DKIM record to your DNS:"
echo "Type: TXT"
echo "Name: ${SELECTOR}._domainkey"
echo "Value: [Copy the value shown above]"
EOF

chmod +x /root/configure-dns.sh

# Final message
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Setup completed successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Next steps:"
echo "1. Configure DNS records at united-domains.de (see /root/server-credentials.txt)"
echo "2. Complete Poste.io setup at https://${MAIL_DOMAIN}"
echo "3. Run /root/configure-dns.sh after Poste.io setup to get DKIM record"
echo ""
echo -e "${YELLOW}Important: Save the credentials from /root/server-credentials.txt${NC}"