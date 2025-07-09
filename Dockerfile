#######################################
# Stage 1 - Build stage
FROM python:3.12-alpine3.19 as build

# Install only essential build dependencies
RUN apk add --no-cache \
    gcc \
    musl-dev \
    libffi-dev \
    openssl-dev

# Copy pip configuration and requirements
COPY build/pip.conf /etc/pip.conf
COPY build/requirements.txt /build/requirements.txt

# Create virtual environment and install Python packages
RUN python -m venv /module/venv
RUN /module/venv/bin/pip install --upgrade pip setuptools wheel
RUN /module/venv/bin/pip install --no-cache-dir -r /build/requirements.txt

# Download and install SOPS (BusyBox wget)
RUN wget --tries=3 \
    https://github.com/mozilla/sops/releases/download/v3.9.0/sops-v3.9.0.linux.amd64 \
    -O /usr/local/bin/sops && \
    chmod +x /usr/local/bin/sops

#######################################
# Stage 2 - Runtime stage
FROM python:3.12-alpine3.19

# Install only runtime dependencies
RUN apk add --no-cache \
    bash \
    ca-certificates \
    curl \
    jq \
    yq \
    gettext \
    age

# Copy virtual environment and SOPS from build stage
COPY --from=build /module /module
COPY --from=build /usr/local/bin/sops /usr/local/bin/sops

# Copy only necessary scripts
COPY scripts/ /module/scripts/

# Create user and set permissions
RUN addgroup -g 1000 ci && \
    adduser -D -u 1000 -h /module/ -s /bin/bash -G ci ci && \
    chown -R ci:ci /module && \
    chmod 755 /module/scripts/* && \
    chmod +x /usr/local/bin/sops

# Set environment
ENV PATH=/module/venv/bin:$PATH \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

# Switch to non-root user
USER ci:ci
WORKDIR /module/scripts

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import sys; sys.exit(0)" || exit 1
