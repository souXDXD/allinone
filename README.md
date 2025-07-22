# System Monitor Script (for Raspberry Pi)

A lightweight Bash script that displays real-time system stats for your Raspberry Pi.
It monitors CPU/SSD temperatures, memory and disk usage, network info, and running services.
The script also logs the highest CPU/SSD temperatures for the last 7 days.


# Table of Contents
Features

How It Works

Requirements

How to Use

Customizable Settings

Example Output

Notes

# Features
Date & time display

Current user

Network info (IP address, Wi-Fi AP mode)

CPU usage & temperature

SSD temperature (via smartctl)

Memory and disk usage

Status of services (Pi-hole, Transmission, etc.)

Top 20 processes using memory

Maintains a 7-day record of max CPU/SSD temperatures


# How It Works
Updates every 30 seconds in a loop

Tracks and stores daily max temperatures

Monitors internet status and key services

Displays available storage info for root and SSD drives

Shows the size of lnp.log (if present)


# Requirements
Most tools are pre-installed on Raspberry Pi OS.
Install smartctl (for SSD temperature):
sudo apt install smartmontools


# Optional tools (if you use these features):
sudo apt install transmission-daemon hostapd


# How to Use
Save the script to a file (e.g., monitor.sh)

Make it executable:
chmod +x monitor.sh

Run it:
./monitor.sh


# Customizable Settings
TEMP_THRESHOLD – Warning temperature (default: 55°C)

MAX_TEMP_DAYS – How many days of temperature history to keep (default: 7 days)

IFACE/WLAN_IF – Network interface names (default: eth0 and wlan0)



# Example Output

Date: Tuesday 22 July 2025 07:40:54 PM IST
Current user: pi
Internet Interface: eth0
IP Address: 192.168.1.201
Uptime: up 3 minutes
Memory Usage: 1091MB / 7821MB
CPU Temp: 38.4'C (max: 43'C)
SSD Temp: 44'C (max: 58'C)

Pi-hole UP
WLAN Interface AP Mode, 192.168.50.1
Transmission Running, 192.168.1.201:9092
Memory Card 33 GB left (55.9% free of 59 GB)
SSD (/mnt/ssd) 38 GB left (8.1% free of 469 GB)


# Notes
The script does not send data anywhere — all output is local
Local IPs (e.g., 192.168.x.x) are safe and only visible on your network
Works best on Raspberry Pi OS or any Debian-based distro
