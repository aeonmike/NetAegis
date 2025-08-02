FROM debian:bullseye

ENV DEBIAN_FRONTEND=noninteractive

# Install required tools and build dependencies
RUN apt update && apt install -y \
    curl gnupg2 ca-certificates wget git \
    build-essential libpcre2-dev libpcre3 libpcre3-dev zlib1g zlib1g-dev libssl-dev \
    libxml2 libxml2-dev libyajl-dev libtool automake autoconf pkgconf \
    libcurl4-openssl-dev doxygen

# Install ModSecurity library
WORKDIR /opt
RUN git clone --depth 1 -b v3/master https://github.com/SpiderLabs/ModSecurity && \
    cd ModSecurity && \
    git submodule update --init --depth 1 && \
    ./build.sh && ./configure && make -j"$(nproc)" && make install

# Get ModSecurity-nginx connector
RUN git clone --depth 1 https://github.com/SpiderLabs/ModSecurity-nginx.git

# Build NGINX with ModSecurity as dynamic module
RUN cd /opt && \
    curl -O http://nginx.org/download/nginx-1.24.0.tar.gz && \
    tar zxvf nginx-1.24.0.tar.gz && \
    cd nginx-1.24.0 && \
    ./configure --with-compat --add-dynamic-module=../ModSecurity-nginx && \
    make -j"$(nproc)" && make install && \
    mkdir -p /usr/local/nginx/modules && \
    cp objs/ngx_http_modsecurity_module.so /usr/local/nginx/modules/

# Enable ModSecurity config with logging
RUN mkdir -p /usr/local/nginx/conf/modsec /var/log/modsec && \
    curl -o /usr/local/nginx/conf/modsec/modsecurity.conf \
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

# Create main ModSecurity config
RUN echo "Include /usr/local/nginx/conf/modsec/modsecurity.conf\n\
Include /usr/local/nginx/conf/modsec-crs/crs-setup.conf\n\
Include /usr/local/nginx/conf/modsec-crs/rules/*.conf" > /usr/local/nginx/conf/modsec/main.conf

# Create a basic HTML page
RUN mkdir -p /usr/local/nginx/html && echo "<h1>NetAegis is Running</h1>" > /usr/local/nginx/html/index.html

# Copy your NGINX config (make sure nginx.conf exists in same folder as Dockerfile)
COPY nginx.conf /usr/local/nginx/conf/nginx.conf

RUN mkdir -p /waf-logs
RUN ln -sf /usr/local/nginx/logs/audit.log /waf-logs/audit.log


# Expose HTTP
EXPOSE 80

# Default command
CMD ["/usr/local/nginx/sbin/nginx", "-g", "daemon off;"]
