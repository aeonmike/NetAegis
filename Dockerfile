FROM debian:bullseye

ENV DEBIAN_FRONTEND=noninteractive
ENV PATH="/usr/local/nginx/sbin:${PATH}"
ENV DB_PATH=/webui/data/users.db

# -------- Accept build arguments for MaxMind credentials --------
ARG MAXMIND_ACCOUNT_ID
ARG MAXMIND_LICENSE_KEY

# -------- Set as environment variables (can also be set at runtime) --------
ENV MAXMIND_ACCOUNT_ID=${MAXMIND_ACCOUNT_ID}
ENV MAXMIND_LICENSE_KEY=${MAXMIND_LICENSE_KEY}

# -------- Install system dependencies ----------
RUN apt update && apt install -y \
    curl gnupg2 ca-certificates wget git \
    build-essential libpcre2-dev libpcre3 libpcre3-dev zlib1g zlib1g-dev libssl-dev \
    libxml2 libxml2-dev libyajl-dev libtool automake autoconf pkgconf \
    libcurl4-openssl-dev doxygen \
    python3 python3-pip python3-dev sqlite3 libsqlite3-dev \
    libmaxminddb-dev cmake g++ wget tar

# -------- Install ModSecurity ----------
WORKDIR /opt
RUN git clone --depth 1 -b v3/master https://github.com/SpiderLabs/ModSecurity && \
    cd ModSecurity && \
    git submodule update --init --depth 1 && \
    ./build.sh && ./configure && make -j"$(nproc)" && make install

# -------- Install ModSecurity-nginx connector ----------
RUN git clone --depth 1 https://github.com/SpiderLabs/ModSecurity-nginx.git

# -------- Install GeoIP2 module for NGINX ----------
RUN git clone --depth 1 https://github.com/leev/ngx_http_geoip2_module.git

# -------- Build NGINX with ModSecurity and GeoIP2 modules ----------
RUN curl -O http://nginx.org/download/nginx-1.24.0.tar.gz && \
    tar zxvf nginx-1.24.0.tar.gz && \
    cd nginx-1.24.0 && \
    ./configure --with-compat \
        --add-dynamic-module=../ModSecurity-nginx \
        --add-dynamic-module=../ngx_http_geoip2_module && \
    make -j"$(nproc)" && make install && \
    cp objs/ngx_http_modsecurity_module.so /usr/local/nginx/modules/ && \
    cp objs/ngx_http_geoip2_module.so /usr/local/nginx/modules/

# -------- Setup ModSecurity and CRS ----------
RUN mkdir -p /usr/local/nginx/conf/modsec /usr/local/nginx/logs /waf-logs /var/log/modsec

RUN curl -o /usr/local/nginx/conf/modsec/modsecurity.conf \
    https://raw.githubusercontent.com/SpiderLabs/ModSecurity/v3/master/modsecurity.conf-recommended && \
    curl -o /usr/local/nginx/conf/modsec/unicode.mapping \
    https://raw.githubusercontent.com/SpiderLabs/ModSecurity/v3/master/unicode.mapping && \
    sed -i 's/SecRuleEngine DetectionOnly/SecRuleEngine On/' /usr/local/nginx/conf/modsec/modsecurity.conf && \
    echo "\
SecAuditEngine On\n\
SecAuditLog /usr/local/nginx/logs/audit.log\n\
SecAuditLogParts ABIJDEFHZ\n\
SecAuditLogType Serial\n\
SecAuditLogFormat JSON\n\
SecDebugLog /var/log/modsec/debug.log\n\
SecDebugLogLevel 3" >> /usr/local/nginx/conf/modsec/modsecurity.conf

# Install OWASP CRS
RUN git clone --depth 1 https://github.com/coreruleset/coreruleset.git /usr/local/nginx/conf/modsec-crs && \
    cp /usr/local/nginx/conf/modsec-crs/crs-setup.conf.example /usr/local/nginx/conf/modsec-crs/crs-setup.conf

# Create ModSecurity main config
RUN echo "Include /usr/local/nginx/conf/modsec/modsecurity.conf\n\
Include /usr/local/nginx/conf/modsec-crs/crs-setup.conf\n\
Include /usr/local/nginx/conf/modsec-crs/rules/*.conf" > /usr/local/nginx/conf/modsec/main.conf

# -------- Install geoipupdate binary directly (no build) ----------
WORKDIR /opt
RUN curl -L -o /usr/local/bin/geoipupdate https://github.com/maxmind/geoipupdate/releases/latest/download/geoipupdate_linux_amd64 && \
    chmod +x /usr/local/bin/geoipupdate

# -------- Copy GeoIP2 NGINX config --------
COPY geoip2.conf /usr/local/nginx/conf/geoip2.conf

# -------- Setup GeoIP2 config and database --------
RUN mkdir -p /usr/share/GeoIP && \
    wget -O /tmp/GeoLite2-Country.tar.gz "https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-Country&license_key=${MAXMIND_LICENSE_KEY}&suffix=tar.gz" && \
    tar -xzf /tmp/GeoLite2-Country.tar.gz -C /tmp && \
    mv /tmp/GeoLite2-Country_*/GeoLite2-Country.mmdb /usr/share/GeoIP/ && \
    rm -rf /tmp/GeoLite2-Country* /tmp/GeoLite2-Country.tar.gz

# -------- Basic content and proxy config directories ----------
RUN mkdir -p /usr/local/nginx/conf/proxies
RUN mkdir -p /usr/local/nginx/html && echo "<h1>NetAegis is Running</h1>" > /usr/local/nginx/html/index.html

# -------- Copy NGINX config ----------
COPY nginx.conf /usr/local/nginx/conf/nginx.conf

# ---------- Setup Python App ----------
WORKDIR /webui

COPY ./waf-webui/requirements.txt .
RUN pip3 install --no-cache-dir -r requirements.txt && pip3 install psutil

COPY ./waf-webui .

# Link ModSecurity log to Flask path
RUN ln -sf /usr/local/nginx/logs/audit.log /waf-logs/audit.log

# -------- Entrypoint --------
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# -------- Expose Ports --------
EXPOSE 80 5000

# -------- Start Services --------
CMD ["/entrypoint.sh"]
