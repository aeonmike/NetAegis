# NetAegis 🔥🛡️  
**Open Source Web Application Firewall (WAF)**


![NetAegis Logo](https://raw.githubusercontent.com/aeonmike/netaegis/main/assets/netaegis-logo.png)


**NetAegis** is a lightweight, open-source Web Application Firewall designed to protect web applications from common threats such as SQL injection, cross-site scripting (XSS), file inclusion, and more. With support for OWASP CRS, GeoIP filtering, and customizable rule sets, NetAegis is ideal for developers, sysadmins, and DevOps teams looking for transparent, high-performance protection.

---

## ✨ Features

- ✅ **Real-Time Threat Detection**  
  Detects and blocks common attacks: SQLi, XSS, RFI, LFI, CSRF, etc.

- 🛡️ **Custom Rule Engine**  
  Supports OWASP Core Rule Set (CRS) and user-defined WAF rules.

- ⚡ **Optimized Performance**  
  Built on Nginx/OpenResty with minimal overhead.

- 🌐 **GeoIP Filtering**  
  Allow or block countries and regions by IP.

- 🔧 **Reverse Proxy Friendly**  
  Works with Nginx, OpenLiteSpeed, and Apache in reverse proxy setups.

- 🔌 **Modular Architecture**  
  Easily extend or integrate with Docker, CI/CD, and modern stacks.

---

## 📦 Installation

### Docker (Quick Start)
```bash
git clone https://github.com/yourname/netaegis.git
cd netaegis
docker-compose up -d
