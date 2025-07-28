#!/system/bin/sh

# Script to reset USB debug toggle session files
# Use this to force USB debug toggle to run again THIS BOOT
# Place in /sdcard/ and run: sh /sdcard/reset_usb_debug_flag.sh

echo "=== USB Debug Toggle Session Reset ==="

# Get current boot ID
CURRENT_BOOT_ID=$(cat /proc/sys/kernel/random/boot_id 2>/dev/null | cut -c1-8)
USB_DEBUG_TOGGLE_SESSION="/data/local/tmp/usb_debug_session_${CURRENT_BOOT_ID}"

echo "Current boot ID: $CURRENT_BOOT_ID"
echo "Current session file: $USB_DEBUG_TOGGLE_SESSION"

# Remove current session file
if [ -f "$USB_DEBUG_TOGGLE_SESSION" ]; then
    rm "$USB_DEBUG_TOGGLE_SESSION"
    echo "✓ Current session flag removed"
    echo "USB debug toggle will run again when service restarts"
else
    echo "! Current session flag not found"
    echo "USB debug toggle will run when service starts"
fi

# Clean up all old session files
cleanup_count=0
for old_file in /data/local/tmp/usb_debug_session_*; do
    if [ -f "$old_file" ]; then
        rm "$old_file" 2>/dev/null
        cleanup_count=$((cleanup_count + 1))
    fi
done

if [ $cleanup_count -gt 0 ]; then
    echo "✓ Cleaned up $cleanup_count old session files"
fi

echo ""
echo "To trigger toggle immediately:"
echo "1. Run this script"
echo "2. Restart the module service or reboot"
echo ""
echo "Session files are automatically cleaned on each boot"