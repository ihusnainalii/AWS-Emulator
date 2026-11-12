#!/usr/bin/env bash

# AWS Emulator CLI for macOS & Linux
# Manages installation, container lifecycle, and shell environment switching.

# Determine if the script is being sourced or executed
IS_SOURCED=false
if [ -n "${ZSH_VERSION:-}" ]; then
    case "${ZSH_EVAL_CONTEXT:-}" in
        *:file*) IS_SOURCED=true ;;
    esac
    SCRIPT_PATH="${(%):-%x}"
elif [ -n "${BASH_VERSION:-}" ]; then
    if [ "${BASH_SOURCE[0]}" != "$0" ]; then
        IS_SOURCED=true
    fi
    SCRIPT_PATH="${BASH_SOURCE[0]}"
else
    SCRIPT_PATH="$0"
fi

PROJECT_DIR="$(cd "$(dirname "${SCRIPT_PATH}")" 2>/dev/null && pwd)"
PORT="9297"
EMULATOR_DIR="${HOME}/.aws/emulator/${PORT}"

# --- Helper: Generate project files ---
generate_files() {
    mkdir -p "${HOME}/.aws/emulator"

    # .dockerignore
    cat << 'EOF' > "${PROJECT_DIR}/.dockerignore"
.git
.gitignore
*.md
emulator.sh
EOF

    # Dockerfile (Multi-arch)
    cat << 'EOF' > "${PROJECT_DIR}/Dockerfile"
FROM public.ecr.aws/amazonlinux/amazonlinux:2023-minimal

ARG TARGETARCH

RUN ARCH="$(uname -m)" \
    && if [ -n "$TARGETARCH" ]; then \
         case "$TARGETARCH" in \
           "arm64") ARCH="aarch64" ;; \
           "amd64") ARCH="x86_64" ;; \
         esac; \
       fi \
    && curl -Lo /tmp/aws-emulator.rpm "https://downloads.aws.com/aws-emulator/packages/aws-emulator/LTS/latest/aws-emulator-${ARCH}.rpm" \
    && rpm -i /tmp/aws-emulator.rpm \
    && rm /tmp/aws-emulator.rpm \
    && mkdir -p /home/emulator/.aws/emulator \
    && chown -R 1000:1000 /home/emulator

USER 1000
ENV HOME=/home/emulator
EXPOSE 9297
ENTRYPOINT ["aws-emulator", "-b", "0.0.0.0"]
EOF

    # docker-compose.yml
    cat << 'EOF' > "${PROJECT_DIR}/docker-compose.yml"
services:
  aws-emulator:
    build:
      context: .
      dockerfile: Dockerfile
    image: aws-emulator:latest
    container_name: aws-emulator
    ports:
      - "127.0.0.1:9297:9297"
    environment:
      - HOME=${HOME}
    volumes:
      - ${HOME}/.aws/emulator:${HOME}/.aws/emulator
    command: ["-a", "off"]
    deploy:
      resources:
        limits:
          memory: 2G
    restart: unless-stopped
EOF
}

# --- Action: Switch current shell to Emulator mode ---
switch_to_emulator() {
    if [ ! -d "${EMULATOR_DIR}" ]; then
        echo "⚠️  Directory ${EMULATOR_DIR} not found. Waiting for emulator..."
        sleep 2
    fi

    # Ensure credentials file exists (emulator in -a off mode accepts any keys)
    if [ ! -f "${EMULATOR_DIR}/emulator_credentials" ]; then
        mkdir -p "${EMULATOR_DIR}"
        cat << 'EOF' > "${EMULATOR_DIR}/emulator_credentials"
[default]
aws_access_key_id = mock_access_key
aws_secret_access_key = mock_secret_key
EOF
    fi

    # Unset real AWS credentials to avoid signature conflicts
    unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_PROFILE

    # Set Emulator environment variables
    export AWS_ENDPOINT_URL="https://127.0.0.1:${PORT}"
    export AWS_SHARED_CREDENTIALS_FILE="${EMULATOR_DIR}/emulator_credentials"
    export AWS_CONFIG_FILE="${EMULATOR_DIR}/config"
    export AWS_CA_BUNDLE="${EMULATOR_DIR}/ca.pem"
    export AWS_EC2_METADATA_DISABLED="true"
    export AWS_DISABLE_HOST_PREFIX_INJECTION="true"
    export AWS_REGION="us-east-1"
    export AWS_DEFAULT_REGION="us-east-1"

    # SDK-specific overrides
    export NODE_EXTRA_CA_CERTS="${EMULATOR_DIR}/ca.pem"
    export SSL_CERT_FILE="${EMULATOR_DIR}/ca.pem"
    export JAVA_TOOL_OPTIONS="-Djavax.net.ssl.trustStore=${EMULATOR_DIR}/truststore.p12 -Djavax.net.ssl.trustStoreType=PKCS12"

    echo "✅ Switched to [EMULATOR MODE] (Port ${PORT})"
    echo "   Endpoint:    ${AWS_ENDPOINT_URL}"
    echo "   CA Bundle:   ${AWS_CA_BUNDLE}"
    echo "   Credentials: ${AWS_SHARED_CREDENTIALS_FILE}"

    if command -v aws >/dev/null 2>&1; then
        echo ""
        echo "Testing connection:"
        aws sts get-caller-identity || true
    fi
}

# --- Action: Switch current shell to Live AWS mode ---
switch_to_live() {
    unset AWS_ENDPOINT_URL
    unset AWS_SHARED_CREDENTIALS_FILE
    unset AWS_CONFIG_FILE
    unset AWS_CA_BUNDLE
    unset AWS_EC2_METADATA_DISABLED
    unset AWS_DISABLE_HOST_PREFIX_INJECTION
    unset NODE_EXTRA_CA_CERTS
    unset SSL_CERT_FILE
    unset JAVA_TOOL_OPTIONS

    echo "☁️  Switched to [LIVE AWS MODE]"
    echo "   Cleared emulator endpoints and cert overrides."
    echo "   Your standard AWS credentials, profiles, and AWS SSO will now be used."

    if command -v aws >/dev/null 2>&1; then
        echo ""
        echo "Current identity:"
        aws sts get-caller-identity || echo "Tip: Log into real AWS using: aws sso login (or configure ~/.aws/credentials)"
    fi
}

# --- Parse arguments ---
ACTION="${1:-}"

case "${ACTION}" in
    install|--install|setup|--setup)
        echo "=== Installing & Setting up AWS Emulator ==="
        echo "-> Verifying Docker daemon..."
        if ! docker info >/dev/null 2>&1; then
            echo "Error: Docker daemon is not running. Please start Docker Desktop and retry." >&2
            exit 1
        fi
        echo "-> Generating configuration files..."
        generate_files
        echo "-> Building Docker image (aws-emulator:latest)..."
        cd "${PROJECT_DIR}"
        docker compose build
        echo ""
        echo "=== Installation Complete! ==="
        echo "Recommended usage:"
        echo "  source emulator.sh start   # Starts container AND switches shell to Emulator"
        echo "  source emulator.sh stop    # Stops container AND switches shell back to Live AWS"
        echo ""
        echo "Tip: Add this function to your ~/.zshrc so you don't need to type 'source':"
        echo "  emulator() { source \"${PROJECT_DIR}/emulator.sh\" \"\$@\"; }"
        ;;
    on|emulator|use-emulator|env)
        if [ "${IS_SOURCED}" = false ]; then
            echo "⚠️  To switch your current terminal session, you MUST source this script:"
            echo "    source emulator.sh on"
            return 1 2>/dev/null || exit 1
        fi
        switch_to_emulator
        ;;
    off|live|use-live|reset)
        if [ "${IS_SOURCED}" = false ]; then
            echo "⚠️  To switch your current terminal session, you MUST source this script:"
            echo "    source emulator.sh off"
            return 1 2>/dev/null || exit 1
        fi
        switch_to_live
        ;;
    start|--start)
        generate_files
        echo "-> Starting AWS Emulator container..."
        cd "${PROJECT_DIR}"
        docker compose up -d
        echo "Waiting for emulator..."
        for i in {1..10}; do
            if curl -ks https://localhost:9297/__admin/health | grep -q "ok"; then
                echo "✅ AWS Emulator is running and healthy!"
                break
            fi
            sleep 1
        done

        if [ "${IS_SOURCED}" = true ]; then
            echo "-> Auto-configuring shell environment..."
            switch_to_emulator
        else
            echo ""
            echo "💡 To automatically switch this terminal to Emulator mode when starting, run:"
            echo "    source emulator.sh start"
            echo "Or switch now with: source emulator.sh on"
        fi
        ;;
    stop|--stop)
        if [ "${IS_SOURCED}" = true ]; then
            echo "-> Auto-switching shell back to Live AWS..."
            switch_to_live
        fi
        echo "-> Stopping AWS Emulator container..."
        cd "${PROJECT_DIR}"
        docker compose down
        echo "Stopped."

        if [ "${IS_SOURCED}" = false ]; then
            echo ""
            echo "💡 To automatically reset your terminal variables when stopping, run:"
            echo "    source emulator.sh stop"
            echo "Or reset now with: source emulator.sh off"
        fi
        ;;
    restart|--restart)
        echo "-> Restarting AWS Emulator container..."
        cd "${PROJECT_DIR}"
        docker compose down
        docker compose up -d
        if [ "${IS_SOURCED}" = true ]; then
            switch_to_emulator
        fi
        echo "Restarted."
        ;;
    status|--status)
        echo "-> Container status:"
        cd "${PROJECT_DIR}"
        docker compose ps
        echo ""
        echo "-> Health check (https://127.0.0.1:9297/__admin/health):"
        curl -k -i https://localhost:9297/__admin/health || true
        ;;
    logs|--logs)
        cd "${PROJECT_DIR}"
        docker compose logs -f
        ;;
    upload)
        shift
        python3 "${PROJECT_DIR}/upload.py" "$@"
        ;;
    shortcut|alias)
        RC_FILE="${HOME}/.zshrc"
        [ -n "${BASH_VERSION:-}" ] && [ ! -f "$RC_FILE" ] && RC_FILE="${HOME}/.bashrc"
        FUNCTION_LINE="emulator() { source \"${PROJECT_DIR}/emulator.sh\" \"\$@\"; }; enumator() { emulator \"\$@\"; }"
        
        if grep -q "emulator()" "${RC_FILE}" 2>/dev/null; then
            echo "Shortcut 'emulator' is already configured in ${RC_FILE}."
        else
            echo "" >> "${RC_FILE}"
            echo "# AWS Emulator shell function" >> "${RC_FILE}"
            echo "${FUNCTION_LINE}" >> "${RC_FILE}"
            echo "✅ Added shortcut to ${RC_FILE}."
        fi
        echo "Run: source ${RC_FILE}"
        echo "Then you can simply type:"
        echo "  emulator start    # Starts Docker + switches shell to Emulator"
        echo "  emulator stop     # Switches shell to Live AWS + stops Docker"
        ;;
    *)
        echo "AWS Emulator CLI"
        echo "Usage (starts/stops container + auto-switches shell when sourced):"
        echo "  source emulator.sh start   Start container & switch terminal to Emulator"
        echo "  source emulator.sh stop    Stop container & switch terminal to Live AWS"
        echo ""
        echo "Other commands:"
        echo "  ./emulator.sh install      Create files and build Docker image"
        echo "  ./emulator.sh upload       Upload file via presigned PUT and get links"
        echo "  ./emulator.sh status       Check container status and health"
        echo "  ./emulator.sh logs         Follow container logs"
        echo "  source emulator.sh on      Switch shell to Emulator only"
        echo "  source emulator.sh off     Switch shell to Live AWS only"
        ;;
esac
