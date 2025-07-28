# --------------------------
# Stage 1: Go build
# --------------------------
FROM golang:1.22 AS builder

# Set working directory matching your Go module name
WORKDIR /go/src/netaegis

# Copy go.mod and go.sum and download dependencies
COPY go.mod go.sum ./
RUN go mod download

# Copy full project source
COPY . .

# Build the Go binary
RUN go build -o netaegis ./cmd/main.go

# --------------------------
# Stage 2: Final image with Debian, Nginx, ModSecurity
# --------------------------
FROM debian:bookworm-slim

# Install required packages
RUN apt-get update && apt-get install -y \
    nginx \
    curl \
    git \
    build-essential \
    libmodsecurity3 \
    libnginx-mod-http-modsecurity \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Copy compiled Go binary from builder
COPY --from=builder /go/src/netaegis/netaegis /usr/local/bin/netaegis

# Copy web templates and static files
COPY --from=builder /go/src/netaegis/templates /app/templates
COPY --from=builder /go/src/netaegis/static /app/static

# Copy ModSecurity configuration (optional: create modsecurity.conf and nginx.conf separately)
COPY modsecurity.conf /etc/modsecurity/
COPY nginx.conf /etc/nginx/nginx.conf

# Create runtime directory for Nginx
RUN mkdir -p /var/run/nginx

# Expose port 80
EXPOSE 80

# Start both the Go app and Nginx
CMD ["/usr/local/bin/netaegis"]
