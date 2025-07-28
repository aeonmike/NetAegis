# Stage 1: Build Go Web UI
FROM golang:1.21 AS builder

WORKDIR /app

# Copy Go source files
COPY go.mod go.sum ./
RUN go mod download

COPY . ./

# Build the Go backend
RUN go build -o netaegis ./cmd/main.go


# Stage 2: Build Final Image with Nginx, ModSecurity, and Web UI
FROM debian:bullseye

ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y \
    nginx \
    curl \
    git \
    build-essential \
    libmodsecurity3 \
    libnginx-mod-http-modsecurity \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Clone and set up OWASP ModSecurity CRS
RUN git clone https://github.com/coreruleset/coreruleset /etc/nginx/modsec-crs && \
    cp /etc/nginx/modsec-crs/crs-setup.conf.example /etc/nginx/modsec-crs/crs-setup.conf

# Copy ModSecurity main config
COPY modsecurity.conf /etc/modsecurity/modsecurity.conf

# Enable ModSecurity in Nginx
RUN echo "Include /etc/nginx/modsec-crs/crs-setup.conf" > /etc/modsecurity/include.conf && \
    echo "Include /etc/nginx/modsec-crs/rules/*.conf" >> /etc/modsecurity/include.conf

# Copy Nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Copy Go Web UI (from builder stage)
COPY --from=builder /app/netaegis /usr/local/bin/netaegis

# Copy web templates and static files
COPY templates/ /app/templates/
COPY static/ /app/static/

# Set working directory
WORKDIR /app

# Expose ports
EXPOSE 80

# Start both Nginx and Golang Web UI
CMD service nginx start && ./netaegis
