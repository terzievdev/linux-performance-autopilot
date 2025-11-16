#!/bin/bash
# Linux Performance Autopilot - Installation and Configuration Script
# Sets up system monitoring and performance analysis tools

set -e

echo "🚀 Linux Performance Autopilot - Setup Script"
echo "=============================================="

# Validate root privileges
if [ "$EUID" -ne 0 ]; then 
    echo "❌ Error: Root privileges required. Execute with: sudo ./setup.sh"
    exit 1
fi

# 1. Install required dependencies
echo "📦 Installing required packages..."
apt-get update -qq
apt-get install -y sysstat bc curl gnuplot stress-ng jq

# 2. Create directory structure
echo "📁 Creating directory structure..."
mkdir -p /opt/autopilot/{scripts,config,logs,reports}
mkdir -p /var/log/autopilot

# 3. Deploy monitoring scripts
echo "📄 Deploying script files..."
cp scripts/*.sh /opt/autopilot/scripts/
chmod +x /opt/autopilot/scripts/*.sh

# 4. Install configuration file
if [ ! -f /opt/autopilot/config/autopilot.conf ]; then
    cp config/autopilot.conf /opt/autopilot/config/
    echo "✅ Configuration file deployed"
else
    echo "⚠️  Configuration file already exists - preserving current version"
fi

# 5. Install and enable systemd service
echo "⚙️  Installing systemd service..."
cp systemd/autopilot.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable autopilot.service

# 6. Start the monitoring service
echo "🔄 Starting Autopilot service..."
systemctl start autopilot.service

# 7. Verify service status
sleep 2
systemctl status autopilot.service --no-pager

echo ""
echo "✅ INSTALLATION COMPLETE! Linux Performance Autopilot is now operational!"
echo ""
echo "📊 Useful Commands:"
echo "  systemctl status autopilot"
echo "  journalctl -u autopilot -f"
echo "  systemctl stop autopilot"
echo "  systemctl restart autopilot"
