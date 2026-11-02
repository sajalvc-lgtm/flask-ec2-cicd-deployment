#!/usr/bin/env bash
# ==============================================================================
# Master Script: Complete Jenkins LTS Setup for Amazon Linux 2023 (EC2)
# Includes: Git, Java 21, Jenkins, DNF mirror fix & Java SSL/PKIX plugin fix
# ==============================================================================
set -e

echo "=========================================================="
echo " Step 1: Update system packages & install required tools"
echo "=========================================================="
sudo dnf update -y
sudo dnf install -y git wget fontconfig ca-certificates openssl
sudo update-ca-trust force-check

echo "=========================================================="
echo " Step 2: Install Java 21 (Amazon Corretto)"
echo "=========================================================="
sudo dnf install -y java-21-amazon-corretto-devel
java -version

echo "=========================================================="
echo " Step 3: Add Jenkins repository (with mirror SSL fix)"
echo "=========================================================="
sudo rm -f /etc/yum.repos.d/jenkins.repo
sudo tee /etc/yum.repos.d/jenkins.repo > /dev/null << 'EOF'
[jenkins]
name=Jenkins-stable
baseurl=https://pkg.jenkins.io/rpm-stable/
gpgcheck=1
sslverify=0
EOF

echo "=========================================================="
echo " Step 4: Import Jenkins GPG Keys"
echo "=========================================================="
sudo rpm --import https://pkg.jenkins.io/rpm-stable/jenkins.io-2026.key || \
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2026.key || \
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key

echo "=========================================================="
echo " Step 5: Install Jenkins package"
echo "=========================================================="
sudo dnf clean all
sudo dnf makecache
sudo dnf install -y jenkins

echo "=========================================================="
echo " Step 6: Fix Java truststore (Prevents PKIX plugin errors)"
echo "=========================================================="
JAVA_BIN=$(readlink -f $(which java))
JAVA_HOME=$(dirname $(dirname "$JAVA_BIN"))
CACERTS="$JAVA_HOME/lib/security/cacerts"

if [ ! -f "$CACERTS" ]; then
    CACERTS=$(find /usr/lib/jvm -name cacerts | head -n 1)
fi

echo "Importing mirror certificates into: $CACERTS"
DOMAINS=("updates.jenkins.io" "get.jenkins.io" "ftp-nyc.osuosl.org" "mirrors.jenkins.io")

for DOMAIN in "${DOMAINS[@]}"; do
    rm -f /tmp/cert_*.crt
    echo | openssl s_client -showcerts -servername "$DOMAIN" -connect "$DOMAIN":443 2>/dev/null | \
        awk 'BEGIN {c=0} /-----BEGIN CERTIFICATE-----/ {c++} {print > ("/tmp/cert_" c ".crt")}'
    
    for CERT_FILE in /tmp/cert_*.crt; do
        if [ -s "$CERT_FILE" ]; then
            ALIAS="${DOMAIN}_$(basename $CERT_FILE .crt)"
            sudo keytool -delete -alias "$ALIAS" -keystore "$CACERTS" -storepass changeit 2>/dev/null || true
            sudo keytool -importcert -noprompt -trustcacerts \
                -alias "$ALIAS" \
                -file "$CERT_FILE" \
                -keystore "$CACERTS" \
                -storepass changeit
        fi
    done
done

echo "=========================================================="
echo " Step 7: Enable and start Jenkins service"
echo "=========================================================="
sudo systemctl daemon-reload
sudo systemctl enable jenkins
sudo systemctl restart jenkins

# Wait for initialAdminPassword generation
sleep 8

echo "=========================================================="
echo " Step 8: Verification"
echo "=========================================================="
sudo systemctl status jenkins --no-pager

TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 60" 2>/dev/null || true)
if [ -n "$TOKEN" ]; then
    PUBLIC_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "<YOUR_EC2_PUBLIC_IP>")
else
    PUBLIC_IP=$(curl -s http://checkip.amazonaws.com 2>/dev/null || echo "<YOUR_EC2_PUBLIC_IP>")
fi

echo ""
echo "=============================================================================="
echo "                   JENKINS SETUP COMPLETE!                                    "
echo "=============================================================================="
echo " 🌐 Open in browser: http://${PUBLIC_IP}:8080"
echo " 👤 Username: admin"
echo " 🔑 Initial Admin Password:"
if [ -f /var/lib/jenkins/secrets/initialAdminPassword ]; then
    sudo cat /var/lib/jenkins/secrets/initialAdminPassword
else
    echo " Run: sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
fi
echo ""
echo " ⚠️  REQUIRED: Open Port 8080 in your AWS EC2 Security Group inbound rules."
echo "=============================================================================="
