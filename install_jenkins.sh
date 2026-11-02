#!/bin/bash
# ==============================================================================
# Script: install_jenkins.sh
# Purpose: Clean, automated setup for Git, Java 21 & Jenkins on Amazon Linux 2023
# Works on: AWS EC2 (t2.medium / t3.medium recommended)
# ==============================================================================

set -e

echo "----------------------------------------------------"
echo " Step 1: Update system & install Git, Wget, Fontconfig"
echo "----------------------------------------------------"
sudo dnf update -y
sudo dnf install git wget fontconfig ca-certificates -y
sudo update-ca-trust force-check

echo "----------------------------------------------------"
echo " Step 2: Install Amazon Corretto Java 21"
echo "----------------------------------------------------"
sudo dnf install java-21-amazon-corretto-devel -y

# Verify Java installation
java -version

echo "----------------------------------------------------"
echo " Step 3: Configure Jenkins Stable Repository"
echo "----------------------------------------------------"
sudo rm -f /etc/yum.repos.d/jenkins.repo

# Using sslverify=0 prevents curl error (60) on third-party OSUOSL mirrors
# Package security is guaranteed by gpgcheck=1 verifying GPG signature
sudo tee /etc/yum.repos.d/jenkins.repo > /dev/null << 'EOF'
[jenkins]
name=Jenkins-stable
baseurl=https://pkg.jenkins.io/rpm-stable/
gpgcheck=1
sslverify=0
EOF

echo "----------------------------------------------------"
echo " Step 4: Import Official Jenkins GPG Keys"
echo "----------------------------------------------------"
sudo rpm --import https://pkg.jenkins.io/rpm-stable/jenkins.io-2026.key || \
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2026.key || \
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key

echo "----------------------------------------------------"
echo " Step 5: Clean package cache & Install Jenkins"
echo "----------------------------------------------------"
sudo dnf clean all
sudo dnf makecache
sudo dnf install jenkins -y

echo "----------------------------------------------------"
echo " Step 6: Enable and Start Jenkins Service"
echo "----------------------------------------------------"
sudo systemctl daemon-reload
sudo systemctl enable jenkins
sudo systemctl start jenkins

# Wait briefly for initialAdminPassword to be generated
sleep 5

echo "----------------------------------------------------"
echo " Step 7: Verify Jenkins Status"
echo "----------------------------------------------------"
sudo systemctl status jenkins --no-pager

# Retrieve Public IP and Admin Password automatically
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 60" 2>/dev/null || true)
if [ -n "$TOKEN" ]; then
    PUBLIC_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "<YOUR_EC2_PUBLIC_IP>")
else
    PUBLIC_IP=$(curl -s http://checkip.amazonaws.com 2>/dev/null || echo "<YOUR_EC2_PUBLIC_IP>")
fi

echo ""
echo "=============================================================================="
echo "                   JENKINS READY TO USE!                                     "
echo "=============================================================================="
echo " Access URL: http://${PUBLIC_IP}:8080"
echo ""
echo " Initial Admin Password:"
if [ -f /var/lib/jenkins/secrets/initialAdminPassword ]; then
    sudo cat /var/lib/jenkins/secrets/initialAdminPassword
else
    echo " (Password file still generating, run: sudo cat /var/lib/jenkins/secrets/initialAdminPassword)"
fi
echo ""
echo " IMPORTANT: Ensure Port 8080 is added to your EC2 Security Group Inbound Rules."
echo "=============================================================================="
