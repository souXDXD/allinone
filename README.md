# System Monitor Script (for Raspberry Pi) -

This script displays real-time system stats, including:

Date & time
Current user
Network info (IP, Wi-Fi AP mode)
CPU usage & temperature
SSD temperature
Memory and disk usage
Status of services (Pi-hole, Transmission, etc.)
Top 20 processes using memory
It also keeps a 7-day record of max CPU/SSD temperatures.


# How It Works -

The script runs in a loop, updating every 30 seconds.
It logs today's highest temperature for CPU and SSD.
It checks if internet and services (like Pi-hole or Transmission) are running.
Displays storage info for root and SSD drives.
Shows the size of lnp.log file (if present).

# Requirements -

Most tools are pre-installed on Raspberry Pi OS.
For SSD temperature, install smartctl:
sudo apt install smartmontools

Optional tools (if you use these features):
sudo apt install transmission-daemon hostapd

# How to Use -

Save the script to a file (e.g., monitor.sh).
Make it executable:
chmod +x - monitor.sh
run it - ./monitor.sh

# Customizable Settings -

TEMP_THRESHOLD – Warning temperature (default: 55°C).
MAX_TEMP_DAYS – How many days of temperature history to keep (default: 7 days).
IFACE/WLAN_IF – Change network interface names if yours are different.
Get SSD temp (NVMe) using smartctl -x - under this change the mount path, if you want to view storage space as well.


# Example output -

Date: Tuesday 22 July 2025 07:40:54 PM IST
Current user: pi
Internet Interface: eth0
IP Address: 192.168.1.201
Uptime: up 3 minutes
Memory Usage: 1091MB / 7821MB
CPU Temp: 38.4'C (max: 43'C)
SSD Temp: 44'C (max: 58'C)

Pi-hole            UP
WLAN Interface     AP Mode, 192.168.50.1
Transmission       Running, 192.168.1.201:9092
Memory Card        33 GB left (55.9% free of 59 GB)
SSD (/mnt/ssd)     38 GB left (8.1% free of 469 GB)


Notes -

The script does not send data anywhere — it only shows info on your terminal.
Local IP addresses (e.g., 192.168.x.x) are safe; they are visible only inside your home network.
