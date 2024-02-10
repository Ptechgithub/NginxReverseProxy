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
    local dependencies=("nginx" "git" "wget" "certbot" "python3-certbot-nginx")
    
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
    (crontab -l 2>/dev/null | grep -v 'certbot renew --nginx --force-renewal --non-interactive --post-hook "nginx -s reload"' ; echo '0 0 1 * * certbot renew --nginx --force-renewal --non-interactive --post-hook "nginx -s reload" > /dev/null 2>&1;') | crontab -
    echo ""
    echo -e "${purple}Certificate and Key saved at:${rest}"
    echo -e "${yellow}×××××××××××××××××××××××××××××××××××××××××××××××××××××${rest}"
    echo -e "${cyan}/etc/letsencrypt/live/$domain/fullchain.pem${rest}"
    echo -e "${cyan}/etc/letsencrypt/live/$domain/privkey.pem${rest}"
    echo -e "${yellow}×××××××××××××××××××××××××××××××××××××××××××××××××××××${rest}"
    echo -e "${cyan}🌟 N R P installed Successfully.🌟${rest}"
    echo -e "${yellow}××××××××××××××××××××××××××××××××${rest}"
  else
    echo ""
    echo -e "${yellow}×××××××××××××××××××××××${rest}"
    echo -e "${red}❌N R P installation failed.❌${rest}"
    echo -e "${yellow}×××××××××××××××××××××××${rest}"
  fi
}

# Change Paths
change_path() {
  if systemctl is-active --quiet nginx && [ -f "/etc/nginx/sites-available/$saved_domain" ]; then
     
    echo -e "${yellow}×××××××××××××××××××××××${rest}"
    read -p "Enter the new GRPC path (Service Name) [default: grpc]: " new_grpc_path
    new_grpc_path=${new_grpc_path:-grpc}
    echo -e "${yellow}×××××××××××××××××××××××${rest}"
    read -p "Enter the new WebSocket path (Service Name) [default: ws]: " new_ws_path
    new_ws_path=${new_ws_path:-ws}
    echo -e "${yellow}×××××××××××××××××××××××${rest}"
    
    sed -i "14s|location ~ .* {$|location ~ ^/${new_grpc_path}/(?<port>\\\d+)/(.*)$ {|" /etc/nginx/sites-available/$saved_domain
    sed -i "28s|location ~ .* {$|location ~ ^/${new_ws_path}/(?<port>\\\d+)$ {|" /etc/nginx/sites-available/$saved_domain
    
    # Restart Nginx
    systemctl restart nginx
    echo -e " ${purple}Paths Changed Successfully${cyan}:
|-----------------|-------|
| GRPC Path       | ${yellow}$new_grpc_path
${cyan}| WebSocket Path  | ${yellow}$new_ws_path  ${cyan}
|-----------------|-------|${rest}"
    echo -e "${yellow}×××××××××××××××××××××××${rest}"
  else
    echo -e "${yellow}×××××××××××××××××××××××${rest}"
    echo -e "${red}N R P is not installed.${rest}"
    echo -e "${yellow}×××××××××××××××××××××××${rest}"
  fi
}

# Install random site
install_random_fake_site() {
    if [ ! -d "/etc/letsencrypt/live/$saved_domain" ]; then
        echo -e "${yellow}×××××××××××××××××××××××${rest}"
        echo -e "${red}Nginx is not installed.${rest}"
        echo -e "${yellow}×××××××××××××××××××××××${rest}"
        exit 1
    fi

    if [ ! -d "/var/www/html" ]; then
        echo -e "${yellow}×××××××××××××××××××××××${rest}"
        echo -e "${red}/var/www/html does not exist.${rest}"
        exit 1
    fi

    if [ ! -d "/var/www/website-templates" ]; then
        echo -e "${yellow}×××××××××××××××××××××××${rest}"
        echo -e "${yellow}Downloading Websites list...${rest}"
        sudo git clone https://github.com/learning-zone/website-templates.git /var/www/website-templates
    fi
    
    cd /var/www/website-templates
    sudo rm -rf /var/www/html/*
    random_folder=$(ls -d */ | shuf -n 1)
    sudo mv "$random_folder"/* /var/www/html
    echo -e "${yellow}×××××××××××××××××××××××${rest}"
    echo -e "${green}Website Installed Successfully${rest}"
    echo -e "${yellow}×××××××××××××××××××××××${rest}"
}

# Limitation
add_limit() {
    # Check if NGINX service is installed
    if [ ! -d "/etc/letsencrypt/live/$saved_domain" ]; then
        echo -e "${yellow}×××××××××××××××××××××××${rest}"
        echo -e "${red}N R P is not installed.${rest}"
        echo -e "${yellow}×××××××××××××××××××××××${rest}"
        exit 1
    fi
    
    echo -e "${yellow}×××××××××××××××××××××××${rest}"
    echo -e "${cyan} This option adds a traffic limit to monitor increases in traffic compared to the last 24 hours.${rest}"
    echo -e "${cyan} If the traffic exceeds this limit, the nginx service will be stopped.${rest}"
    read -p "Enter the percentage limit [default: 50]: " percentage_limit
    percentage_limit=${percentage_limit:-50}
    echo -e "${yellow}×××××××××××××××××××××××${rest}"

    if [ ! -d "/root/usage" ]; then
        mkdir -p /root/usage
    fi
    
    cat <<EOL > /root/usage/limit.sh
#!/bin/bash

# Define the interface
interface=\$(ip -o link show | awk -F': ' '{print \$2}' | grep -v "lo" | head -n 1)

# Current total traffic data
get_total(){
    data=\$(grep "\$interface:" /proc/net/dev)
    download=\$(echo "\$data" | awk '{print \$2}')
    upload=\$(echo "\$data" | awk '{print \$10}')
    total_mb=\$(echo "scale=2; (\$download + \$upload) / 1024 / 1024" | bc)
    echo "\$total_mb"
}

# Check traffic increase
check_traffic_increase() {
    current_total_mb=\$(get_total)

    # Check if file exists
    if [ -f "/root/usage/\${interface}_traffic.txt" ]; then
        # Read the traffic data from file
        read -r prev_total_mb < "/root/usage/\${interface}_traffic.txt"

        # Calculate traffic increase percentage
        increase=\$(echo "scale=2; (\$current_total_mb - \$prev_total_mb) / \$prev_total_mb * 100" | bc)
        # Display message if traffic increase is greater than \$percentage_limit%
        if (( \$(echo "\$increase > $percentage_limit" | bc) )); then
            sudo systemctl stop nginx
            echo "[$(date +'%Y-%m-%d %H:%M:%S')] Traffic on interface \$interface increased by more than $percentage_limit% compared to previous:" >> /root/usage/log.txt
        fi
    fi

    # Save current traffic data to file
    echo "\$current_total_mb" > "/root/usage/\${interface}_traffic.txt"
}

check_traffic_increase
EOL

# Set execute permission for the created script
chmod +x /root/usage/limit.sh && /root/usage/limit.sh

# Schedule the script to run every 24 hours using cron job
(crontab -l 2>/dev/null | grep -v '/root/usage/limit.sh' ; echo '0 0 * * * /root/usage/limit.sh > /dev/null 2>&1;') | crontab -
}

# Change port
change_port() {
    if [ -f "/etc/nginx/sites-available/$saved_domain" ]; then
        current_port=$(grep -oP "listen \[::\]:\K\d+" "/etc/nginx/sites-available/$saved_domain" | head -1)
        echo -e "${yellow}×××××××××××××××××××××××${rest}"
        echo -e "${cyan}Current HTTPS port: ${purple}$current_port${rest}"
        echo -e "${yellow}×××××××××××××××××××××××${rest}"
        read -p "Enter the new HTTPS port: " new_port
        echo -e "${yellow}×××××××××××××××××××××××${rest}"

        # Change the port in NGINX configuration file
        sed -i "s/listen \[::\]:$current_port ssl http2 ipv6only=on;/listen [::]:$new_port ssl http2 ipv6only=on;/g" "/etc/nginx/sites-available/$saved_domain"
        sed -i "s/listen $current_port ssl http2;/listen $new_port ssl http2;/g" "/etc/nginx/sites-available/$saved_domain"
        
        # Restart NGINX service
        systemctl restart nginx

        # Check if NGINX restarted successfully
        if systemctl is-active --quiet nginx; then
            echo -e "${green}✅ HTTPS port changed successfully to ${purple}$new_port${rest}"
        else
            echo -e "${red}❌ Error: NGINX failed to restart.${rest}"
        fi
        echo -e "${yellow}×××××××××××××××××××××××${rest}"
    else
        echo -e "${yellow}×××××××××××××××××××××××××××××××××××${rest}"
        echo -e "${red}N R P is not installed.${rest}"
        echo -e "${yellow}×××××××××××××××××××××××××××××××××××${rest}"
    fi
}

# Uninstall N R P
uninstall() {
  # Check if NGINX is installed
  if [ ! -d "/etc/letsencrypt/live/$saved_domain" ]; then
    echo -e "${yellow}×××××××××××××××××××××××${rest}"
    echo -e "${red}N R P is not installed.${rest}"
    echo -e "${yellow}×××××××××××××××××××××××${rest}"
  else
      echo -e "${green}☑️Uninstalling... ${rest}"
	  # Remove SSL certificate files
	  rm -rf /etc/letsencrypt > /dev/null 2>&1
	  rm -rf /var/www/html/* > /dev/null 2>&1
	
	  # Remove NGINX configuration files
	  find /etc/nginx/sites-available/ -mindepth 1 -maxdepth 1 ! -name 'default' -exec rm -rf {} +
	  find /etc/nginx/sites-enabled/ -mindepth 1 -maxdepth 1 ! -name 'default' -exec rm -rf {} +
	
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
echo -e "${yellow} 2) ${green}Change Paths${rest}      ${purple}*${rest}"
echo -e "${purple}                      * ${rest}"
echo -e "${yellow} 3) ${green}Change Https Port${rest} ${purple}*${rest}"
echo -e "${purple}                      * ${rest}"
echo -e "${yellow} 4) ${green}Install Fake Site${rest} ${purple}*${rest}"
echo -e "${purple}                      * ${rest}"
echo -e "${yellow} 5) ${green}Add Traffic Limit${rest} ${purple}*${rest}"
echo -e "${purple}                      * ${rest}"
echo -e "${yellow} 6) ${green}Uninstall${rest}         ${purple}*${rest}"
echo -e "${purple}                      * ${rest}"
echo -e "${yellow} 0) ${purple}Exit${rest}${purple}              *${rest}"
echo -e "${purple}***********************${rest}"
read -p "Enter your choice: " choice
case "$choice" in
    1)
        install
        ;;
    2)
        change_path
        ;;
    3)
        change_port
        ;;
    4)
        install_random_fake_site
        ;;
    5)
        add_limit
        ;;
    6)
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