<div align="center">
  <h1>⚡ zen2-power-fedora</h1>
  <p><b>Automated power and thermal optimization for ThinkPads running AMD Zen 2 on Fedora Linux.</b></p>

  ![OS: Fedora](https://img.shields.io/badge/OS-Fedora_44+-294172?style=flat-square&logo=fedora&logoColor=white)
  ![CPU: AMD Ryzen](https://img.shields.io/badge/CPU-AMD_Ryzen_Zen_2-ed1c24?style=flat-square&logo=amd&logoColor=white)
  ![Language: Bash](https://img.shields.io/badge/Language-Bash-4EAA25?style=flat-square&logo=gnu-bash&logoColor=white)
  ![License: MIT](https://img.shields.io/badge/License-MIT-yellow?style=flat-square)
</div>

---

A single script that installs and configures everything needed for intelligent power management on Zen 2 ThinkPads. Once run, your laptop automatically switches between a high-performance AC profile and a cool-and-quiet battery profile — no manual intervention required.

## ✨ Features

| | Feature | Description |
|---|---|---|
| 🔋 | **Dynamic Power Switching** | `udev` rules instantly detect charger plug / unplug events and apply the correct profile. |
| 🚀 | **High-Performance AC Profile** | Raises STAPM to **22 W** and thermal ceiling to **90 °C** — sustained boost clocks for demanding workloads. |
| ❄️ | **Cool & Quiet Battery Profile** | Drops STAPM to **10 W** and thermal ceiling to **75 °C** — silent fans, cool chassis, extended battery life. |
| 🧠 | **Smart Frequency Scaling** | Installs and enables [`auto-cpufreq`](https://github.com/AdnanHodzic/auto-cpufreq) for intelligent CPU governor management. |
| 🛠️ | **Source Compilation** | Automatically builds [`ryzenadj`](https://github.com/FlyGoat/RyzenAdj) and the [`ryzen_smu`](https://github.com/leogx9r/ryzen_smu) DKMS kernel module for your running kernel. |

## 📊 Power Profiles

| Parameter | 🔌 AC | 🔋 Battery |
|---|:---:|:---:|
| STAPM Limit | 22 W | 10 W |
| Fast Limit | 25 W | 12 W |
| Slow Limit | 22 W | 10 W |
| Tctl Temp | 90 °C | 75 °C |

> [!TIP]
> These values are defined as constants at the top of the script and can be easily adjusted to suit your hardware or preferences.

## 🔧 How It Works

```
                  ┌──────────────┐
                  │  udev event  │
                  │  (AC online) │
                  └──────┬───────┘
                         │
              ┌──────────┴──────────┐
              │                     │
        online == 1           online == 0
              │                     │
              ▼                     ▼
   ryzenadj-ac.service    ryzenadj-battery.service
              │                     │
              ▼                     ▼
     ryzen-profile-ac       ryzen-profile-battery
       (22W / 90°C)           (10W / 75°C)
```

1. **`udev`** watches `/sys/class/power_supply/` for charger state changes.
2. A matching rule triggers the appropriate **systemd oneshot service**.
3. The service executes a **profile script** that calls `ryzenadj` with the target power limits.
4. **`auto-cpufreq`** runs continuously in the background, dynamically adjusting the CPU governor based on load and power state.

## ⚠️ Prerequisites

Before running the script, ensure your system meets these requirements:

* **Operating System** — Fedora Linux (tested on Fedora 44+).
* **Hardware** — AMD Ryzen Mobile processor (designed and tested on the **ThinkPad T14s Gen 1** with **Ryzen 5 PRO 4650U** "Renoir", but applicable to most Zen 2 mobile chips).
* **Internet Connection** — required to install packages via `dnf` and clone repositories from GitHub.
* **Sudo Privileges** — the script must be run as a normal user who can invoke `sudo`.

> [!WARNING]
> **Secure Boot:** This script builds an out-of-tree kernel module (`ryzen_smu`) via DKMS. Fedora's kernel lockdown will block it if Secure Boot is fully enforced without enrolled keys.
>
> Either **disable Secure Boot** in your ThinkPad's BIOS before running, or be prepared to **enroll the auto-generated MOK** (Machine Owner Key) on the next reboot.

## 📦 Installation

```bash
# Clone the repository
git clone https://github.com/themix88/zen2-power-fedora.git
cd zen2-power-fedora

# Make the script executable
chmod +x 'Ryzen_5_PRO_4650u - FEDORA.sh'

# Run it (do NOT use sudo — the script calls sudo internally)
./Ryzen_5_PRO_4650u\ -\ FEDORA.sh
```

The script will walk through **7 steps** automatically:

| Step | Action |
|:---:|---|
| 1/7 | Install kernel headers, DKMS, and build tools |
| 2/7 | Build and install `ryzenadj` from source |
| 3/7 | Install `auto-cpufreq` (dnf or source fallback) |
| 4/7 | Build and install `ryzen_smu` DKMS module |
| 5/7 | Create power-profile scripts in `/usr/local/bin` |
| 6/7 | Install systemd services and udev rules |
| 7/7 | Enable services and apply initial profile |

## ✅ Post-Install Verification

After the script completes, verify everything is working:

```bash
# Check that the ryzen_smu module is loaded
lsmod | grep ryzen_smu

# Check auto-cpufreq status
systemctl status auto-cpufreq

# View the currently applied power limits
sudo ryzenadj --info

# Manually trigger a profile (optional)
sudo systemctl start ryzenadj-ac.service       # AC profile
sudo systemctl start ryzenadj-battery.service   # Battery profile
```

## 🔩 Tuning

To adjust the power limits, edit the constants at the top of the script:

```bash
# Power-profile tunables (milliwatts / °C)
readonly AC_STAPM=22000    AC_FAST=25000    AC_SLOW=22000    AC_TCTL=90
readonly BAT_STAPM=10000   BAT_FAST=12000   BAT_SLOW=10000   BAT_TCTL=75
```

Then re-run the script to regenerate the profile scripts and services.

> [!CAUTION]
> Setting power limits too high or thermal ceilings beyond your cooling solution's capacity can cause thermal throttling, instability, or reduced component lifespan. Increase values conservatively and monitor thermals with `ryzenadj --info`.

## 🙏 Credits

* [RyzenAdj](https://github.com/FlyGoat/RyzenAdj) — Adjust power management settings for Ryzen Mobile processors
* [ryzen_smu](https://github.com/leogx9r/ryzen_smu) — Linux kernel driver for AMD SMU access
* [auto-cpufreq](https://github.com/AdnanHodzic/auto-cpufreq) — Automatic CPU speed & power optimizer for Linux
