#!/bin/bash
# ==============================================================================
# Script: fix_jenkins_ssl.sh
# Fixes: Java PKIX path building failed / SSLHandshakeException in Jenkins
# ==============================================================================
set -e

echo "==> Finding Java cacerts truststore..."
JAVA_BIN=$(readlink -f $(which java))
JAVA_HOME=$(dirname $(dirname "$JAVA_BIN"))
CACERTS="$JAVA_HOME/lib/security/cacerts"

if [ ! -f "$CACERTS" ]; then
    CACERTS=$(find /usr/lib/jvm -name cacerts | head -n 1)
fi

echo "Found keystore: $CACERTS"

# Domains used by Jenkins Update Center & Download Mirrors
DOMAINS=("updates.jenkins.io" "get.jenkins.io" "ftp-nyc.osuosl.org" "mirrors.jenkins.io")

for DOMAIN in "${DOMAINS[@]}"; do
    echo "==> Fetching certificates for $DOMAIN..."
    rm -f /tmp/cert_*.crt
    
    # Extract full certificate chain and split into individual certs
    echo | openssl s_client -showcerts -servername "$DOMAIN" -connect "$DOMAIN":443 2>/dev/null | \
        awk 'BEGIN {c=0} /-----BEGIN CERTIFICATE-----/ {c++} {print > ("/tmp/cert_" c ".crt")}'
    
    for CERT_FILE in /tmp/cert_*.crt; do
        if [ -s "$CERT_FILE" ]; then
            ALIAS="${DOMAIN}_$(basename $CERT_FILE .crt)"
            echo "Importing $ALIAS into Java truststore..."
            # Delete if alias already exists, then import
            sudo keytool -delete -alias "$ALIAS" -keystore "$CACERTS" -storepass changeit 2>/dev/null || true
            sudo keytool -importcert -noprompt -trustcacerts \
                -alias "$ALIAS" \
                -file "$CERT_FILE" \
                -keystore "$CACERTS" \
                -storepass changeit
        fi
    done
done

echo "==> Restarting Jenkins service..."
sudo systemctl restart jenkins

echo "==> Done! Refresh or click 'Retry' in your browser."
