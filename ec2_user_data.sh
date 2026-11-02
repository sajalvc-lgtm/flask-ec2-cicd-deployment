#!/bin/bash
# ==============================================================================
# AWS EC2 User Data Script for Amazon Linux 2023
# Paste this into "Advanced Details -> User Data" when launching a fresh EC2 instance.
# Jenkins will be installed, configured, and running automatically on boot!
# ==============================================================================

# Redirect all output to log file for troubleshooting
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "==> Step 1: Updating packages and installing dependencies..."
dnf update -y
dnf install -y git wget fontconfig ca-certificates openssl
update-ca-trust force-check

echo "==> Step 2: Installing Amazon Corretto Java 21..."
dnf install -y java-21-amazon-corretto-devel

echo "==> Step 3: Setting up Jenkins Repo with SSL mirror fix..."
tee /etc/yum.repos.d/jenkins.repo > /dev/null << 'EOF'
[jenkins]
name=Jenkins-stable
baseurl=https://pkg.jenkins.io/rpm-stable/
gpgcheck=1
sslverify=0
EOF

echo "==> Step 4: Importing Jenkins GPG Keys..."
rpm --import https://pkg.jenkins.io/rpm-stable/jenkins.io-2026.key || \
rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key

echo "==> Step 5: Installing Jenkins..."
dnf clean all
dnf makecache
dnf install -y jenkins

echo "==> Step 6: Pre-importing mirror SSL certificates to prevent PKIX plugin errors..."
JAVA_BIN=$(readlink -f $(which java))
JAVA_HOME=$(dirname $(dirname "$JAVA_BIN"))
CACERTS="$JAVA_HOME/lib/security/cacerts"
[ ! -f "$CACERTS" ] && CACERTS=$(find /usr/lib/jvm -name cacerts | head -n 1)

DOMAINS=("updates.jenkins.io" "get.jenkins.io" "ftp-nyc.osuosl.org" "mirrors.jenkins.io")
for DOMAIN in "${DOMAINS[@]}"; do
    rm -f /tmp/cert_*.crt
    echo | openssl s_client -showcerts -servername "$DOMAIN" -connect "$DOMAIN":443 2>/dev/null | \
        awk 'BEGIN {c=0} /-----BEGIN CERTIFICATE-----/ {c++} {print > ("/tmp/cert_" c ".crt")}'
    for CERT_FILE in /tmp/cert_*.crt; do
        if [ -s "$CERT_FILE" ]; then
            ALIAS="${DOMAIN}_$(basename $CERT_FILE .crt)"
            keytool -delete -alias "$ALIAS" -keystore "$CACERTS" -storepass changeit 2>/dev/null || true
            keytool -importcert -noprompt -trustcacerts \
                -alias "$ALIAS" \
                -file "$CERT_FILE" \
                -keystore "$CACERTS" \
                -storepass changeit
        fi
    done
done

echo "==> Step 7: Starting and enabling Jenkins service..."
systemctl daemon-reload
systemctl enable jenkins
systemctl start jenkins

echo "==> Jenkins setup complete!"
