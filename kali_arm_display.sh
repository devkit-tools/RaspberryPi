#!/usr/bin/env bash
set -euo pipefail

# Kali ARM Raspberry Pi 3.5" SPI TFT Installer
# Target: 3.5" 480x320 / ILI9486 / XPT2046 / SPI Display
# Default driver: MHS35-show
#
# Usage:
#   sudo bash install_tft_kali.sh
#   sudo bash install_tft_kali.sh mhs35
#   sudo bash install_tft_kali.sh lcd35
#   sudo bash install_tft_kali.sh restore-hdmi

MODE="${1:-mhs35}"
WORKDIR="/opt/LCD-show-kali"
REPO="https://github.com/lcdwiki/LCD-show-kali.git"

echo "[+] Kali ARM Raspberry Pi TFT Installer"
echo "[+] Mode: $MODE"

if [[ "$EUID" -ne 0 ]]; then
  echo "[-] Bitte mit sudo starten:"
  echo "    sudo bash $0"
  exit 1
fi

echo "[+] Systeminfo:"
cat /etc/os-release || true
uname -a || true
cat /proc/device-tree/model 2>/dev/null || true
echo

CONFIG=""
if [[ -f /boot/firmware/config.txt ]]; then
  CONFIG="/boot/firmware/config.txt"
elif [[ -f /boot/config.txt ]]; then
  CONFIG="/boot/config.txt"
else
  echo "[-] Keine Raspberry-Pi config.txt gefunden."
  echo "[-] Erwartet: /boot/firmware/config.txt oder /boot/config.txt"
  exit 1
fi

echo "[+] Benutze config: $CONFIG"

BACKUP_DIR="/root/tft-backup-$(date +%F-%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "[+] Erstelle Backup nach: $BACKUP_DIR"
cp -a "$CONFIG" "$BACKUP_DIR/config.txt.backup"

if [[ -f /boot/cmdline.txt ]]; then
  cp -a /boot/cmdline.txt "$BACKUP_DIR/cmdline.txt.backup"
fi

if [[ -f /boot/firmware/cmdline.txt ]]; then
  cp -a /boot/firmware/cmdline.txt "$BACKUP_DIR/firmware-cmdline.txt.backup"
fi

if [[ "$MODE" == "restore-hdmi" ]]; then
  echo "[+] Versuche HDMI über LCD-show-kali wiederherzustellen..."

  apt update
  apt install -y git

  rm -rf "$WORKDIR"
  git clone "$REPO" "$WORKDIR"
  chmod -R 755 "$WORKDIR"
  cd "$WORKDIR"

  echo "[+] Starte LCD-hdmi Restore..."
  ./LCD-hdmi || true

  echo "[+] Fertig. Reboot empfohlen:"
  echo "    sudo reboot"
  exit 0
fi

echo "[+] Installiere Abhängigkeiten..."
apt update
apt install -y git curl wget ca-certificates xserver-xorg-input-evdev xinput-calibrator

echo "[+] Aktiviere SPI in config.txt, falls noch nicht vorhanden..."
if ! grep -qE '^\s*dtparam=spi=on' "$CONFIG"; then
  echo "dtparam=spi=on" >> "$CONFIG"
fi

echo "[+] Entferne alte lokale LCD-show-kali Kopie..."
rm -rf "$WORKDIR"

echo "[+] Klone LCD-show-kali..."
git clone "$REPO" "$WORKDIR"
chmod -R 755 "$WORKDIR"
cd "$WORKDIR"

echo "[+] Verfügbare Display-Skripte:"
ls -1 *show 2>/dev/null || true
echo

case "$MODE" in
  mhs35|MHS35)
    DRIVER="./MHS35-show"
    ;;
  lcd35|LCD35)
    DRIVER="./LCD35-show"
    ;;
  *)
    echo "[-] Unbekannter Mode: $MODE"
    echo "    Nutze:"
    echo "      sudo bash $0 mhs35"
    echo "      sudo bash $0 lcd35"
    echo "      sudo bash $0 restore-hdmi"
    exit 1
    ;;
esac

if [[ ! -x "$DRIVER" ]]; then
  echo "[-] Driver-Script nicht gefunden oder nicht ausführbar: $DRIVER"
  echo "[-] Inhalt von $WORKDIR:"
  ls -la
  exit 1
fi

echo
echo "[!] Wichtig:"
echo "    Das Script wird wahrscheinlich Display-Konfig ändern und danach rebooten."
echo "    Wenn der Bildschirm danach schwarz/weiß bleibt, per SSH verbinden und ausführen:"
echo "    sudo bash $0 restore-hdmi"
echo
echo "[+] Starte Display-Treiber: $DRIVER"
sleep 3

"$DRIVER"

echo "[+] Fertig. Falls kein automatischer Reboot passiert:"
echo "    sudo reboot"
