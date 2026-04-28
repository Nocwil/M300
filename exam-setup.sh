#!/bin/bash

# Make executable and run. Copy-paste: chmod +x exam-setup.sh && ./exam-setup.sh

set -e  # Exit on error

# Update package list
echo "[1/5] Updating package list..."
sudo apt-get update -qq

# Install git if not present
echo "[2/5] Ensuring git is installed..."
sudo apt-get install -y git wget

# Download and install MarkText
echo "[3/5] Installing MarkText..."
cd /tmp
wget -q https://github.com/marktext/marktext/releases/download/v0.17.1/marktext-amd64.deb
sudo dpkg -i marktext-amd64.deb || sudo apt-get install -f -y
rm marktext-amd64.deb

# Clone M300 repository
echo "[4/5] Cloning M300 exam materials..."
cd ~
if [ -d "m300" ]; then
    echo "    m300 directory already exists, pulling latest..."
    cd m300
    git pull
else
    git clone https://github.com/Nocwil/M300.git
    cd m300
fi

# Install optional useful tools
echo "[5/5] Installing additional tools..."
sudo apt-get install -y \
    curl \
    net-tools \
    dnsutils \
    bind9-utils \
    tree \
    htop

echo ""
echo "========================================="
echo "✓ Setup Complete!"
echo "========================================="
echo ""
echo "Cheat-sheets location: ~/m300/cheat-sheets/"
echo ""
echo "To open cheat-sheets in MarkText:"
echo "  1. Open MarkText from applications menu"
echo "  2. File → Open → Navigate to ~/m300/cheat-sheets/"
echo "  3. Open 00-MASTER-EXAM-CHEAT-SHEET.md"
echo ""

