#!/system/bin/sh

# Autoboot on Charger
# Reference: https://github.com/anasfanani/magisk-autoboot

# Only run on recovery (charger mode)
if grep -qE 'androidboot.mode=charger|ro.bootmode=charger' /proc/cmdline 2>/dev/null; then
  echo "Charger mode detected, triggering reboot..." | log -t autoboot
  sleep 2
  reboot
fi