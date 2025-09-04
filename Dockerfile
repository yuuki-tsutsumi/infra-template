FROM hashicorp/terraform

# Install system dependencies
RUN apk add --no-cache --update \
  python3 \
  py3-pip \
  gcc \
  musl-dev \
  python3-dev \
  libffi-dev \
  openssl-dev \
  cargo \
  make

# Create and activate a virtual environment for Azure CLI
RUN python3 -m venv /opt/venv \
  && . /opt/venv/bin/activate \
  && pip install --upgrade pip \
  && pip install --no-cache-dir azure-cli \
  && deactivate

# Clean up unnecessary build tools
RUN apk del \
  gcc \
  musl-dev \
  python3-dev \
  libffi-dev \
  openssl-dev \
  cargo \
  make \
  && rm -rf /var/cache/apk/*

# Update PATH to include the virtual environment
ENV PATH="/opt/venv/bin:$PATH"
