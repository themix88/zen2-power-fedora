<div align="center">
  <h1>⚡ zen2-power-fedora</h1>
  <p><b>Automated power and thermal optimization script for ThinkPads running AMD Zen 2 CPUs on Fedora Linux.</b></p>

  ![OS: Fedora](https://img.shields.io/badge/OS-Fedora-294172?style=flat-square&logo=fedora&logoColor=white)
  ![CPU: AMD Ryzen](https://img.shields.io/badge/CPU-AMD_Ryzen_Zen_2-ed1c24?style=flat-square&logo=amd&logoColor=white)
  ![Language: Bash](https://img.shields.io/badge/Language-Bash-4EAA25?style=flat-square&logo=gnu-bash&logoColor=white)
</div>

---

This script completely automates the installation and configuration of Ryzen power management tools on Fedora. It seamlessly handles background state switching between AC and Battery without any manual intervention, keeping your laptop fast when plugged in and quiet on the go.

## ✨ Features

* **🔋 Dynamic Power Switching:** Uses `udev` rules to instantly detect when your charger is plugged in or disconnected and automatically applies the correct power profile.
* **🚀 High-Performance AC Profile:** Safely raises the STAPM limit to **22W** and the thermal ceiling to **90°C**. Prevents aggressive thermal throttling and sustains higher boost clocks for demanding tasks.
* **❄️ Cool & Quiet Battery Profile:** Drops the STAPM limit to **10W** and the thermal ceiling to **75°C**. Keeps the laptop cool to the touch, stops the fans from spinning up, and significantly extends battery life.
* **🧠 Smart Frequency Scaling:** Automatically downloads, installs, and enables `auto-cpufreq` to intelligently manage CPU governor states alongside the power limits.
* **🛠️ Source Compilation:** Automatically fetches the necessary C++ dependencies, clones the latest GitHub repositories, and builds both `ryzenadj` and the `ryzen_smu` DKMS kernel module specifically for your current Fedora kernel.

## ⚠️ Prerequisites

Before running the installation script, ensure your system meets the following requirements:

* **Operating System:** Fedora Linux (Tested on Fedora 44+).
* **Hardware:** AMD Ryzen Mobile processor (Specifically designed and tested on the ThinkPad T14s Gen 1 with Ryzen 5 PRO 4650U "Renoir", but applies to most Zen 2 mobile chips).
* **Internet Connection:** Required to download packages via `dnf` and clone repositories from GitHub.
* **Secure Boot:** Because this script builds an out-of-tree kernel module (`ryzen_smu`) via DKMS, Fedora's strict kernel lockdown will block it if Secure Boot is fully enforced without enrolled keys.
  > **Recommendation:** Either disable Secure Boot in your ThinkPad's BIOS before running, OR be prepared to enroll the auto-generated MOK (Machine Owner Key) upon your next reboot.
