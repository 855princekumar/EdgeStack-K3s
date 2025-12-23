#!/usr/bin/env python3
import subprocess
import sys

def ask(prompt, default=None):
    val = input(f"{prompt} [{default}]: ").strip()
    return val or default

def run(cmd):
    subprocess.run(cmd, check=True)

print("\n--- Static IP Configuration ---\n")

iface = ask("Network interface", "eth0")
ip = ask("Static IP (CIDR)", "192.168.1.50/24")
gw = ask("Gateway", "192.168.1.1")
dns = ask("DNS servers (comma separated)", "8.8.8.8,8.8.4.4")

dns_list = dns.replace(",", " ")

print("\nApplying configuration:")
print(f" Interface : {iface}")
print(f" IP        : {ip}")
print(f" Gateway   : {gw}")
print(f" DNS       : {dns_list}")

confirm = input("\nProceed? (y/N): ").lower()
if confirm != "y":
    print("Aborted.")
    sys.exit(0)

run(["nmcli", "con", "show", iface])
run(["nmcli", "con", "modify", iface,
     "ipv4.method", "manual",
     "ipv4.addresses", ip,
     "ipv4.gateway", gw,
     "ipv4.dns", dns_list])
run(["nmcli", "con", "down", iface])
run(["nmcli", "con", "up", iface])

print("Static IP applied successfully.")
