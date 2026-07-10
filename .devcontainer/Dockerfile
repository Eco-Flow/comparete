FROM mcr.microsoft.com/devcontainers/base:ubuntu

# Install common build tools, Java runtime, and curl
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    unzip \
    git \
    ca-certificates \
    openjdk-17-jre-headless \
    && rm -rf /var/lib/apt/lists/*

# Install Nextflow
RUN curl -s https://get.nextflow.io | bash && mv nextflow /usr/local/bin/nextflow

# Install nf-test optionally if wanted
RUN curl -fsSL https://code.askimed.com/install/nf-test | bash || true

# Ensure /usr/local/bin is on PATH
ENV PATH="/usr/local/bin:${PATH}"
ENV JAVA_HOME="/usr/lib/jvm/java-17-openjdk-amd64"
