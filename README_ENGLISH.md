# NGINX Reverse Proxy Installer

## Installation
```
bash <(curl -fsSL https://raw.githubusercontent.com/Ptechgithub/NginxReverseProxy/main/install.sh)
```
![20](https://github.com/Ptechgithub/configs/blob/main/media/20.jpg)

---

This script is used to install and configure NGINX Reverse Proxy on Linux servers. By running this script, you can quickly and automatically configure a web server as a proxy to route traffic to other applications (such as GRPC and WebSocket services).
Obtain an SSL certificate and install a free website template.

---

## Usage
First, create an A record in your CDN, such as Cloudflare, and point your domain or subdomain to the server's IP address and enable the proxy option.

In the Network settings section, enable the GRPC option.

In the SSL/TLS encryption mode section, select the Full option.

After running the script, enter your desired domain and follow the installation steps.

By selecting the "install fake site" option, a total of `170` website templates will be downloaded, and a template will be randomly installed. Selecting this option will delete the previous template and quickly install a new one for subsequent uses.

During installation, port 80 must be open and not in use by another service so that the SSL certificate can be obtained. After installation, the port is available, and you can use it.

After the service is installed, Nginx works on port `443` by default and this port must be available and not in use by another service. However, you can change this port to another HTTPS port using the script and use port `443` in your other services.

You can apply traffic restrictions with option `5`. Its functionality is such that after selecting this option, it will ask you for a specific percentage, and after entering it, you will enable a script that calculates your usage every `24` hours. If your usage after `24` hours is higher than the percentage you specified initially (for example, if tomorrow's usage is `50%` higher than today's), the command `systemctl stop nginx` will be executed, and the service will be stopped, and the log will be saved in the `/root/usage` directory. To restart, simply enter the command `systemctl start nginx` or reboot the server. Note: After rebooting the server, the usage will be calculated from zero.

Client images are in gif format. Click on them to play if they are static.

The script will obtain an SSL certificate for your domain and apply NGINX Reverse Proxy settings. Finally, it will give you the path to the certificate, which you can use in your panel.
In this script, you choose the `Path` yourself.
For use in the `x-ui` panel, simply follow the steps below for grpc and ws:

---

## Configuring WebSocket

### Panel

![21](https://raw.githubusercontent.com/Ptechgithub/configs/main/media/21.jpg)

---

### Client

![23](https://raw.githubusercontent.com/Ptechgithub/configs/main/media/23.gif)

---
---
---

## Configuring GRPC

### Panel

![22](https://raw.githubusercontent.com/Ptechgithub/configs/main/media/22.jpg)

---

### Client

![24](https://raw.githubusercontent.com/Ptechgithub/configs/main/media/24.gif)

[website-templates](https://github.com/learning-zone)