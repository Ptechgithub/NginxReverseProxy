#!/bin/bash

#colors
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
blue='\033[0;34m'
purple='\033[0;35m'
cyan='\033[0;36m'
rest='\033[0m'

# Check for root user
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

# Detect the Linux distribution
detect_distribution() {
    
    local supported_distributions=("ubuntu" "debian" "centos" "fedora")
    
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        if [[ "${ID}" = "ubuntu" || "${ID}" = "debian" || "${ID}" = "centos" || "${ID}" = "fedora" ]]; then
            p_m="apt-get"
            [ "${ID}" = "centos" ] && p_m="yum"
            [ "${ID}" = "fedora" ] && p_m="dnf"
        else
            echo "Unsupported distribution!"
            exit 1
        fi
    else
        echo "Unsupported distribution!"
        exit 1
    fi
}

# Check dependencies
check_dependencies() {
    detect_distribution
    sudo "${p_m}" -y update && sudo "${p_m}" -y upgrade
    local dependencies=("nginx" "certbot" "python3-certbot-nginx")
    
    for dep in "${dependencies[@]}"; do
        if ! command -v "${dep}" &> /dev/null; then
            echo -e "${yellow}${dep} is not installed. Installing...${rest}"
            sudo "${p_m}" install "${dep}" -y
        fi
    done
}

# Display error and exit
display_error() {
  echo -e "${red}Error: $1${rest}"
  exit 1
}

# Store domain name
d_f="/etc/nginx/d.txt"
# Read domain from file
saved_domain=$(cat "$d_f" 2>/dev/null)


# Install Reverse nginx
install() {
    # Check if NGINX is already installed
	if [ -d "/etc/letsencrypt/live/$saved_domain" ]; then
	    echo -e "${yellow}×××××××××××××××××××××××${rest}"
		echo -e "${cyan}N R P${green} is already installed.${rest}"
		echo -e "${yellow}×××××××××××××××××××××××${rest}"
		exit 0
	else
	# Ask the user for the domain name
	echo -e "${yellow}×××××××××××××××××××××××${rest}"
	read -p "Enter your domain name: " domain
	echo -e "${yellow}×××××××××××××××××××××××${rest}"
	read -p "Enter GRPC Path (Service Name) [default: grpc]: " grpc_path
	grpc_path=${grpc_path:-grpc}
	echo -e "${yellow}×××××××××××××××××××××××${rest}"
	read -p "Enter WebSocket Path (Service Name) [default: ws]: " ws_path
	ws_path=${ws_path:-ws}
	echo -e "${yellow}×××××××××××××××××××××××${rest}"
	check_dependencies
	
	echo "$domain" > "$d_f"
	# Copy default NGINX config to your website
	sudo cp /etc/nginx/sites-available/default "/etc/nginx/sites-available/$domain" || display_error "Failed to copy NGINX config"
	
	# Enable your website
	sudo ln -s "/etc/nginx/sites-available/$domain" "/etc/nginx/sites-enabled/" || display_error "Failed to enable your website"
	
	# Remove default_server from the copied config
	sudo sed -i -e 's/listen 80 default_server;/listen 80;/g' \
	              -e 's/listen \[::\]:80 default_server;/listen \[::\]:80;/g' \
	              -e "s/server_name _;/server_name $domain;/g" "/etc/nginx/sites-available/$domain" || display_error "Failed to modify NGINX config"
	
	# Restart NGINX service
	sudo systemctl restart nginx || display_error "Failed to restart NGINX service"
	
	# Allow ports in firewall
	sudo ufw allow 80/tcp || display_error "Failed to allow port 80"
	sudo ufw allow 443/tcp || display_error "Failed to allow port 443"
	
	# Get a free SSL certificate
	echo -e "${yellow}×××××××××××××××××××××××${rest}"
	echo -e "${green}Get SSL certificate ${rest}"
	sudo certbot --nginx -d "$domain" --register-unsafely-without-email --non-interactive --agree-tos --redirect || display_error "Failed to obtain SSL certificate"
	
	# NGINX config file content
	cat <<EOL > /etc/nginx/sites-available/$domain
server {
        root /var/www/html;
        
        # Add index.php to the list if you are using PHP
        index index.html index.htm index.nginx-debian.html;
        server_name $domain;
        
        location / {
                # First attempt to serve request as file, then
                # as directory, then fall back to displaying a 404.
                try_files \$uri \$uri/ =404;
        }
        # GRPC configuration
	    location ~ ^/$grpc_path/(?<port>\d+)/(.*)$ {
	        if (\$content_type !~ "application/grpc") {
	            return 404;
	        }
	        set \$grpc_port \$port;
	        client_max_body_size 0;
	        client_body_buffer_size 512k;
	        grpc_set_header X-Real-IP \$remote_addr;
	        client_body_timeout 1w;
	        grpc_read_timeout 1w;
	        grpc_send_timeout 1w;
	        grpc_pass grpc://127.0.0.1:\$grpc_port;
	    }
	    # WebSocket configuration
	    location ~ ^/$ws_path/(?<port>\d+)$ {
	        if (\$http_upgrade != "websocket") {
	            return 404;
	        }
	        set \$ws_port \$port;
	        proxy_pass http://127.0.0.1:\$ws_port/;
	        proxy_redirect off;
	        proxy_http_version 1.1;
	        proxy_set_header Upgrade \$http_upgrade;
	        proxy_set_header Connection "upgrade";
	        proxy_set_header Host \$host;
	        proxy_set_header X-Real-IP \$remote_addr;
	        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
	    }
	
    listen [::]:443 ssl http2 ipv6only=on; # managed by Certbot
    listen 443 ssl http2; # managed by Certbot
    ssl_certificate /etc/letsencrypt/live/$domain/fullchain.pem; # managed by Certbot
    ssl_certificate_key /etc/letsencrypt/live/$domain/privkey.pem; # managed by Certbot
    include /etc/letsencrypt/options-ssl-nginx.conf; # managed by Certbot
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; # managed by Certbot
}
server {
    if (\$host = $domain) {
        return 301 https://\$host\$request_uri;
    } # managed by Certbot
        listen 80;
        listen [::]:80;
        server_name $domain;
    return 404; # managed by Certbot
}
EOL
	
	# Restart NGINX service
	sudo systemctl restart nginx || display_error "Failed to restart NGINX service"
	check_installation
    fi
}

# Check installation statu
check_status() {
	if systemctl is-active --quiet nginx && [ -f "/etc/nginx/sites-available/$saved_domain" ] > /dev/null 2>&1; then
	  echo -e "${green} 🌐 Service Installed.${rest}"
	else
	  echo -e "${red}🌐Service Not installed${rest}"
	fi
}

# Function to check installation status
check_installation() {
  if systemctl is-active --quiet nginx && [ -f "/etc/nginx/sites-available/$domain" ]; then
    echo ""
    echo -e "${Purple}Certificate and Key saved at:${rest}"
    echo -e "${yellow}×××××××××××××××××××××××××××××××××××××××××××××××××××××${rest}"
    echo -e "${cyan}/etc/letsencrypt/live/$domain/fullchain.pem${rest}"
    echo -e "${cyan}/etc/letsencrypt/live/$domain/privkey.pem${rest}"
    echo -e "${yellow}×××××××××××××××××××××××××××××××××××××××××××××××××××××${rest}"
    echo -e "${cyan}🌟 N R P installed Successfully.🌟${rest}"
    echo -e "${yellow}××××××××××××××××××××××××××××××××${rest}"
    exit 0
  else
    echo ""
    echo -e "${yellow}×××××××××××××××××××××××${rest}"
    echo -e "${red}❌N R P installation failed.❌${rest}"
    echo -e "${yellow}×××××××××××××××××××××××${rest}"
    exit 1
  fi
}

# Uninstall N R P
uninstall() {
  # Check if NGINX is installed
  if [ ! -d "/etc/letsencrypt/live/$saved_domain" ]; then
    echo -e "${yellow}×××××××××××××××××××××××${rest}"
    echo -e "${red}N R P is not installed.${rest}"
    echo -e "${yellow}×××××××××××××××××××××××${rest}"
    exit 0
  else
      echo -e "${green}☑️Uninstalling... ${rest}"
	  # Remove SSL certificate files
	  rm -rf /etc/letsencrypt > /dev/null 2>&1
	  rm -rf /etc/letsencrypt > /dev/null 2>&1
	
	  # Remove NGINX configuration files
	  rm /etc/nginx/sites-available/$saved_domain > /dev/null 2>&1
	  rm /etc/nginx/sites-enabled/$saved_domain > /dev/null 2>&1
	
	  # Restart NGINX service
	  systemctl restart nginx
	   
	  echo -e "${yellow}××××××××××××××××××××××××××××××${rest}"
	  echo -e "${green}N R P uninstalled successfully.${rest}"
	  echo -e "${yellow}××××××××××××××××××××××××××××××${rest}"
  fi
}

clear
echo -e "${cyan}By --> Peyman * Github.com/Ptechgithub * ${rest}"
echo ""
check_status
echo -e "${purple}***********************${rest}"
echo -e "${yellow}* ${cyan}N${green}ginx ${cyan}R${green}everse ${cyan}P${green}roxy${yellow} *${rest}"
echo -e "${purple}***********************${rest}"
echo -e "${yellow} 1) ${green}Install           ${purple}*${rest}"
echo -e "${purple}                      * ${rest}"
echo -e "${yellow} 2) ${green}Uninstall${rest}         ${purple}*${rest}"
echo -e "${purple}                      * ${rest}"
echo -e "${yellow} 0) ${purple}Exit${rest}${purple}              *${rest}"
echo -e "${purple}***********************${rest}"
read -p "Enter your choice: " choice
case "$choice" in
    1)
        install
        check_installation
        ;;
    2)
        uninstall
        ;;
    0)
        echo -e "${cyan}By 🖐${rest}"
        exit
        ;;
    *)
        echo -e "${yellow}××××××××××××××××××××××××××××××${rest}"
        echo "Invalid choice. Please select a valid option."
        echo -e "${yellow}××××××××××××××××××××××××××××××${rest}"
        ;;
esac