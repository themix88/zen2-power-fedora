#!/usr/bin/env bash
# ============================================================================
#  zen2-power-fedora
#  ThinkPad T14s Gen 1 (Ryzen 5 PRO 4650U) — Power Optimization for Fedora
# ----------------------------------------------------------------------------
#  Automates the installation and configuration of ryzenadj, ryzen_smu, and
#  auto-cpufreq with automatic AC / Battery profile switching via udev.
#
#  Usage:  ./Ryzen_5_PRO_4650u\ -\ FEDORA.sh
#  Note:   Run as a normal user with sudo privileges — NOT as root.
# ============================================================================

set -euo pipefail

# ------------------------------- Constants ----------------------------------

readonly SCRIPT_NAME="zen2-power-fedora"

# Power-profile tunables (milliwatts / °C)
readonly AC_STAPM=22000    AC_FAST=25000    AC_SLOW=22000    AC_TCTL=90
readonly BAT_STAPM=10000   BAT_FAST=12000   BAT_SLOW=10000   BAT_TCTL=75

# Paths
readonly RYZENADJ_BIN="/usr/local/bin/ryzenadj"
readonly PROFILE_AC="/usr/local/bin/ryzen-profile-ac"
readonly PROFILE_BAT="/usr/local/bin/ryzen-profile-battery"
readonly SMU_MODULE="ryzen_smu"
readonly SMU_CONF="/etc/modules-load.d/${SMU_MODULE}.conf"
readonly UDEV_RULE="/etc/udev/rules.d/99-ryzenadj-power.rules"

# Build directories
readonly BUILD_DIR_RYZENADJ="/tmp/ryzenadj"
readonly BUILD_DIR_SMU="/tmp/ryzen_smu"
readonly BUILD_DIR_AUTOCPUFREQ="/tmp/auto-cpufreq"

# ------------------------------ Formatting ----------------------------------

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

log()     { echo -e "${BLUE}${BOLD}[INFO]${NC}  $1"; }
success() { echo -e "${GREEN}${BOLD}[ OK ]${NC}  $1"; }
warn()    { echo -e "${RED}${BOLD}[WARN]${NC}  $1"; }
die()     { echo -e "${RED}${BOLD}[FAIL]${NC}  $1" >&2; exit 1; }

# ----------------------------- Helpers --------------------------------------

# Print a section header to visually separate major steps.
section() {
  echo ""
  echo -e "${BOLD}── $1${NC}"
}

# Clone a git repo into a target directory, cleaning any previous clone first.
clone_fresh() {
  local repo="$1" dest="$2"
  [[ -d "$dest" ]] && sudo rm -rf "$dest"
  git clone --depth 1 "$repo" "$dest"
}

# ========================== Pre-flight Checks ===============================

if [[ "$EUID" -eq 0 ]]; then
  die "Do not run this script as root. Run it as your normal user with sudo privileges."
fi

echo ""
echo -e "${BOLD}${BLUE}  ⚡ ${SCRIPT_NAME}${NC}"
echo -e "  Power optimisation for ThinkPad T14s Gen 1 · Fedora"
echo ""

# ========================== 1. Dependencies =================================

section "1/7  Installing kernel headers, DKMS, and build tools"

sudo dnf install -y \
  kernel-devel kernel-headers dkms \
  gcc gcc-c++ git cmake make \
  pciutils-devel

success "Build dependencies installed."

# ========================== 2. RyzenAdj =====================================

section "2/7  Building ryzenadj from source"

clone_fresh "https://github.com/FlyGoat/RyzenAdj.git" "$BUILD_DIR_RYZENADJ"

cmake -S "$BUILD_DIR_RYZENADJ" -B "${BUILD_DIR_RYZENADJ}/build" -DCMAKE_BUILD_TYPE=Release
cmake --build "${BUILD_DIR_RYZENADJ}/build" -j "$(nproc)"
sudo cmake --install "${BUILD_DIR_RYZENADJ}/build"

success "ryzenadj installed to ${RYZENADJ_BIN}."

# ========================== 3. auto-cpufreq ==================================

section "3/7  Installing auto-cpufreq"

if ! sudo dnf install -y auto-cpufreq 2>/dev/null; then
  log "Package not found in default repos — building from source…"
  clone_fresh "https://github.com/AdnanHodzic/auto-cpufreq.git" "$BUILD_DIR_AUTOCPUFREQ"
  (cd "$BUILD_DIR_AUTOCPUFREQ" && sudo ./auto-cpufreq-installer --install)
fi

success "auto-cpufreq installed."

# ========================== 4. ryzen_smu DKMS ================================

section "4/7  Building ryzen_smu kernel module (DKMS)"

clone_fresh "https://github.com/leogx9r/ryzen_smu.git" "$BUILD_DIR_SMU"

(cd "$BUILD_DIR_SMU" && sudo make dkms-install)

log "Loading ${SMU_MODULE} module…"
sudo modprobe "$SMU_MODULE" || warn "modprobe failed — module may load after reboot."

echo "$SMU_MODULE" | sudo tee "$SMU_CONF" >/dev/null

success "${SMU_MODULE} installed and configured for auto-load."

# ========================== 5. Profile Scripts ===============================

section "5/7  Creating power-profile scripts"

sudo tee "$PROFILE_AC" >/dev/null <<EOF
#!/usr/bin/env bash
# AC profile — ${AC_STAPM/000/}W STAPM, max ${AC_TCTL}°C
exec ${RYZENADJ_BIN} \\
  --stapm-limit=${AC_STAPM}  --fast-limit=${AC_FAST} \\
  --slow-limit=${AC_SLOW}    --tctl-temp=${AC_TCTL}
EOF

sudo tee "$PROFILE_BAT" >/dev/null <<EOF
#!/usr/bin/env bash
# Battery profile — ${BAT_STAPM/000/}W STAPM, max ${BAT_TCTL}°C
exec ${RYZENADJ_BIN} \\
  --stapm-limit=${BAT_STAPM}  --fast-limit=${BAT_FAST} \\
  --slow-limit=${BAT_SLOW}    --tctl-temp=${BAT_TCTL}
EOF

sudo chmod +x "$PROFILE_AC" "$PROFILE_BAT"

success "Profile scripts created (${PROFILE_AC}, ${PROFILE_BAT})."

# ========================== 6. systemd + udev ================================

section "6/7  Installing systemd services and udev rules"

# --- AC service ---
sudo tee /etc/systemd/system/ryzenadj-ac.service >/dev/null <<EOF
[Unit]
Description=Apply RyzenAdj AC Power Profile
After=multi-user.target

[Service]
Type=oneshot
ExecStart=${PROFILE_AC}

[Install]
WantedBy=multi-user.target
EOF

# --- Battery service ---
sudo tee /etc/systemd/system/ryzenadj-battery.service >/dev/null <<EOF
[Unit]
Description=Apply RyzenAdj Battery Power Profile
After=multi-user.target

[Service]
Type=oneshot
ExecStart=${PROFILE_BAT}

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload

# --- udev rule ---
sudo tee "$UDEV_RULE" >/dev/null <<EOF
# Automatically switch power profiles on charger plug / unplug
SUBSYSTEM=="power_supply", ATTR{online}=="1", RUN+="/usr/bin/systemctl start ryzenadj-ac.service"
SUBSYSTEM=="power_supply", ATTR{online}=="0", RUN+="/usr/bin/systemctl start ryzenadj-battery.service"
EOF

sudo udevadm control --reload-rules

success "systemd services and udev rules installed."

# ========================== 7. Enable & Apply ================================

section "7/7  Activating services"

log "Disabling power-profiles-daemon to prevent conflicts…"
sudo systemctl disable --now power-profiles-daemon.service 2>/dev/null || true

log "Enabling auto-cpufreq…"
sudo systemctl enable --now auto-cpufreq 2>/dev/null || true

log "Applying initial power profile…"
if [[ "$(cat /sys/class/power_supply/AC*/online 2>/dev/null || echo 0)" -eq 1 ]]; then
  sudo systemctl start ryzenadj-ac.service
  success "AC profile applied (${AC_STAPM/000/}W STAPM, ${AC_TCTL}°C)."
else
  sudo systemctl start ryzenadj-battery.service
  success "Battery profile applied (${BAT_STAPM/000/}W STAPM, ${BAT_TCTL}°C)."
fi

# ================================ Done ======================================

echo ""
echo -e "${GREEN}${BOLD}  ✔  ${SCRIPT_NAME} — setup complete!${NC}"
echo ""
