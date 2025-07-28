#!/system/bin/sh

# Auto USB Tether + Charger Cutoff Uninstaller

# Reset USB to default state
svc usb setFunctions mtp 2>/dev/null

# Re-enable charging if it was disabled
for path in /sys/class/power_supply/battery /sys/class/power_supply/BAT0 /sys/class/power_supply/BAT1; do
    if [ -f "$path/charging_enabled" ]; then
        echo 1 > "$path/charging_enabled" 2>/dev/null
        break
    fi
done

# Optional: Remove toggle files (uncomment if desired)
# rm -f /sdcard/usb_tether_toggle.txt
# rm -f /sdcard/auto_charger_cutoff.txt

echo "Module uninstalled, USB and charging reset to default"