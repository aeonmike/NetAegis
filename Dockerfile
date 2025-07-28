# Stage 1: Build Golang Web UI
FROM golang:1.21 AS builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .

RUN CGO_ENABLED=0 GOOS=linux go build -o netaegis ./cmd/main.go

# Stage 2: Debian Base + Nginx + ModSecurity + CRS + NetAegis
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y \
    nginx \
    libnginx-mod-security \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Enable ModSecurity and configure it
RUN mkdir -p /etc/modsecurity /etc/nginx/modsec

# Use recommended ModSecurity config
RUN curl -L https://raw.githubusercontent.com/SpiderLabs/ModSecurity/v3/master/modsecurity.conf-recommended \
    -o /etc/modsecurity/modsecurity.conf && \
    sed -i 's/SecRuleEngine DetectionOnly/SecRuleEngine On/' /etc/modsecurity/modsecurity.conf

# Download a
