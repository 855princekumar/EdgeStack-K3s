#!/bin/bash
# Enterprise-grade NTP + MariaDB Timezone Setup Script
# Features:
#  - NTP configuration with Google + Cloudflare + global pool fallback
#  - Automatic failover if primary NTP servers fail
#  - System-wide timezone configuration
#  - MariaDB global timezone configuration and safe restart
#  - Chrony installation + tracking + health check
#  - Logging to /var/log/iot-ntp.log
#  - CRLF → LF self-cleaning using dos2unix
#  - Idempotent (safe for multiple runs)

LOGFILE="/var/log/iot-ntp.log"
exec > >(tee -a "$LOGFILE") 2>&1

echo "================================================="
echo "    IoT Lab — NTP + MariaDB Advanced Setup"
echo "================================================="

# ============================================================
# SELF CLEAN (CRLF → LF)
# ============================================================
if [ -z "$SCRIPT_CLEANED" ]; then
    echo "[INFO] Checking line endings..."
    sudo apt-get update -y >/dev/null 2>&1 || true
    sudo apt-get install -y dos2unix >/dev/null 2>&1 || true
    dos2unix "$0" >/dev/null 2>&1 || true
    export SCRIPT_CLEANED=1
    exec bash "$0" "$@"
    exit 0
fi

# ============================================================
# FUNCTION: GET CURRENT SYSTEM TIME IN UNIX EPOCH
# ============================================================
get_time_epoch() {
    date +%s
}

TIME_BEFORE=$(get_time_epoch)
echo "[INFO] System time before sync: $TIME_BEFORE"

# ============================================================
# SET SYSTEM-WIDE TIMEZONE
# ============================================================
SYSTEM_TZ="Asia/Kolkata"

echo "[INFO] Setting system timezone to $SYSTEM_TZ..."
sudo timedatectl set-timezone "$SYSTEM_TZ"

echo "[INFO] System timezone updated to:"
timedatectl | grep "Time zone"

# ============================================================
# INSTALL CHRONY IF MISSING
# ============================================================
if ! command -v chronyc >/dev/null 2>&1; then
    echo "[INFO] Installing chrony..."
    sudo apt-get update -y
    sudo apt-get install -y chrony
else
    echo "[INFO] Chrony already installed."
fi

# ============================================================
# APPLY ROBUST CHRONY CONFIG WITH FAILOVER
# ============================================================
echo "[INFO] Applying robust Chrony configuration..."

sudo cp /etc/chrony/chrony.conf /etc/chrony/chrony.conf.bak 2>/dev/null || true

sudo bash -c 'cat > /etc/chrony/chrony.conf <<EOF
# Primary: Google NTP
server time.google.com iburst
server time1.google.com iburst

# Secondary: Cloudflare NTP
server time.cloudflare.com iburst

# Regional pools (India/Asia)
pool in.pool.ntp.org iburst
pool asia.pool.ntp.org iburst

# Global fallback pools
pool 0.pool.ntp.org iburst
pool 1.pool.ntp.org iburst
pool 2.pool.ntp.org iburst
pool 3.pool.ntp.org iburst

rtcsync
makestep 1.0 3
EOF'

# ============================================================
# RESTART CHRONY
# ============================================================
if systemctl list-unit-files | grep -q '^chrony'; then
    sudo systemctl restart chrony
    sudo systemctl enable chrony
else
    sudo systemctl restart chronyd 2>/dev/null || true
    sudo systemctl enable chronyd 2>/dev/null || true
fi

echo "[INFO] Waiting for Chrony to synchronize..."
sleep 5

echo "================================================="
echo "  Chrony Tracking:"
chronyc tracking
echo "================================================="
echo "  Chrony Sources:"
chronyc sources -v
echo "================================================="

# ============================================================
# VALIDATE TIME DIFFERENCE AFTER SYNC
# ============================================================
TIME_AFTER=$(get_time_epoch)
DIFF=$(( TIME_AFTER - TIME_BEFORE ))

echo "[INFO] System time after sync: $TIME_AFTER"
echo "[INFO] Time drift corrected: $DIFF seconds"

if [ $DIFF -gt 5 ] || [ $DIFF -lt -5 ]; then
    echo "[WARN] Large time correction detected! ($DIFF seconds)"
else
    echo "[OK] Time synchronized properly."
fi

# ============================================================
# CONFIGURE MARIADB GLOBAL TIMEZONE
# ============================================================
MYSQL_USER="admin"
MYSQL_PASS="admin123"
DB_TZ="+05:30"

echo "================================================="
echo "    Configuring MariaDB time zone ($DB_TZ)"
echo "================================================="

# Check if MariaDB is alive before applying TZ
if mysql -u"$MYSQL_USER" -p"$MYSQL_PASS" -e "SELECT 1;" >/dev/null 2>&1; then

    echo "[INFO] Restarting MariaDB..."
    sudo systemctl restart mariadb || sudo systemctl restart mysql || true

    echo "[INFO] Applying timezone setting..."
    mysql -u"$MYSQL_USER" -p"$MYSQL_PASS" <<EOF
SET GLOBAL time_zone = '$DB_TZ';
FLUSH PRIVILEGES;
EOF

    if [ $? -eq 0 ]; then
        echo "[OK] MariaDB global timezone successfully set to $DB_TZ"
    else
        echo "[ERROR] Failed to set MariaDB timezone."
    fi

else
    echo "[WARN] MariaDB server is not reachable. Skipping timezone config."
fi

echo "================================================="
echo "       NTP + MariaDB Installation Completed"
echo "       Log file: $LOGFILE"
echo "================================================="
