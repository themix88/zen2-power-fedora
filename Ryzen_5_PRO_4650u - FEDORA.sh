#!/usr/bin/env bash
#
# ThinkPad T14s Gen 1 (Ryzen 5 PRO 4650U) Power Optimization Script for Fedora
#

set -e

# Color helpers
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
error() {
  echo -e "${RED}[ERROR]${NC} $1"
  exit 1
}

# 1. Root Check
if [ "$EUID" -eq 0 ]; then
  error "Do not run this script as root directly. Run it as your normal user with sudo privileges."
fi

log "Starting setup for ThinkPad T14s Gen 1 on Fedora..."

# 2. Install Development Headers and Build Tools
log "Installing kernel headers, DKMS, and development tools..."
sudo dnf install -y kernel-devel kernel-headers dkms gcc gcc-c++ git cmake make pciutils-devel

# 3. Build and Install ryzenadj from Source
log "Cloning and building ryzenadj from source..."
if [ -d "/tmp/ryzenadj" ]; then
  sudo rm -rf /tmp/ryzenadj
fi

git clone https://github.com/FlyGoat/RyzenAdj.git /tmp/ryzenadj
cd /tmp/ryzenadj
mkdir build && cd build
cmake ..
make -j$(nproc)
sudo make install
cd -

# 4. Install auto-cpufreq
log "Installing auto-cpufreq..."
sudo dnf install -y auto-cpufreq || {
  log "auto-cpufreq not in default dnf repos, installing via git..."
  git clone https://github.com/AdnanHodzic/auto-cpufreq.git /tmp/auto-cpufreq
  cd /tmp/auto-cpufreq && sudo ./auto-cpufreq-installer --install
  cd -
}

# 5. Build and Install ryzen_smu-dkms (GitHub source)
log "Cloning and installing ryzen_smu driver via DKMS..."
if [ -d "/tmp/ryzen_smu" ]; then
  sudo rm -rf /tmp/ryzen_smu
fi

git clone https://github.com/leogx9r/ryzen_smu.git /tmp/ryzen_smu
cd /tmp/ryzen_smu
sudo make dkms-install
cd -

# 6. Load Kernel Module & Configure Persistence
log "Loading ryzen_smu module..."
sudo modprobe ryzen_smu || true

log "Setting up ryzen_smu auto-load on boot..."
echo "ryzen_smu" | sudo tee /etc/modules-load.d/ryzen_smu.conf >/dev/null

# 7. Create Profile Scripts
log "Creating power profile scripts in /usr/local/bin..."

# AC Profile: 22W STAPM limit, max 90°C
sudo tee /usr/local/bin/ryzen-profile-ac >/dev/null <<'EOF'
#!/bin/bash
/usr/local/bin/ryzenadj --stapm-limit=22000 --fast-limit=25000 --slow-limit=22000 --tctl-temp=90
EOF

# Battery Profile: 10W STAPM limit, max 75°C
sudo tee /usr/local/bin/ryzen-profile-battery >/dev/null <<'EOF'
#!/bin/bash
/usr/local/bin/ryzenadj --stapm-limit=10000 --fast-limit=12000 --slow-limit=10000 --tctl-temp=75
EOF

sudo chmod +x /usr/local/bin/ryzen-profile-ac /usr/local/bin/ryzen-profile-battery

# 8. Create systemd Services
log "Setting up systemd services..."

sudo tee /etc/systemd/system/ryzenadj-ac.service >/dev/null <<'EOF'
[Unit]
Description=Apply RyzenAdj AC Power Profile
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/ryzen-profile-ac

[Install]
WantedBy=multi-user.target
EOF

sudo tee /etc/systemd/system/ryzenadj-battery.service >/dev/null <<'EOF'
[Unit]
Description=Apply RyzenAdj Battery Power Profile
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/ryzen-profile-battery

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload

# 9. Configure udev Rule for Automatic AC/Battery Switching
log "Setting up udev rules for power state switching..."

sudo tee /etc/udev/rules.d/99-ryzenadj-power.rules >/dev/null <<'EOF'
SUBSYSTEM=="power_supply", ATTR{online}=="1", RUN+="/usr/bin/systemctl start ryzenadj-ac.service"
SUBSYSTEM=="power_supply", ATTR{online}=="0", RUN+="/usr/bin/systemctl start ryzenadj-battery.service"
EOF

sudo udevadm control --reload-rules

# 10. Enable auto-cpufreq Service
log "Disabling default power-profiles-daemon to prevent conflicts..."
sudo systemctl disable --now power-profiles-daemon.service || true

log "Enabling auto-cpufreq service..."
sudo systemctl enable --now auto-cpufreq || true

# 11. Initial Profile Trigger
log "Applying power profile based on current AC state..."
if [ "$(cat /sys/class/power_supply/AC*/online 2>/dev/null || echo 0)" -eq 1 ]; then
  sudo systemctl start ryzenadj-ac.service
  log "Applied AC Profile (22W)."
else
  sudo systemctl start ryzenadj-battery.service
  log "Applied Battery Profile (10W)."
fi

success "Script setup for FEDORA is complete!"
