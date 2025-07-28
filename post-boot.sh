#!/system/bin/sh

# Additional script to ensure tethering works after boot
# This runs after the main service.sh with additional delay

TETHER_TOGGLE="/sdcard/usb_tether_toggle.txt"
log_tag="post_boot_tether"

# Wait for full system ready
sleep 30

echo "Post-boot tethering check started" | log -t $log_tag

# Check if tethering should be enabled
toggle=$(cat "$TETHER_TOGGLE" 2>/dev/null || echo "1")

if [ "$toggle" = "1" ]; then
    # Force enable mobile data first
    svc data enable 2>/dev/null
    sleep 5
    
    # Check if we have mobile data
    mobile_data=$(settings get global mobile_data 2>/dev/null)
    if [ "$mobile_data" != "1" ]; then
        echo "Enabling mobile data..." | log -t $log_tag
        settings put global mobile_data 1 2>/dev/null
        sleep 3
    fi
    
    # Now ensure USB tethering is properly configured
    usb_state=$(getprop sys.usb.state 2>/dev/null)
    CURRENT_BOOT_ID=$(cat /proc/sys/kernel/random/boot_id 2>/dev/null | cut -c1-8)
    USB_DEBUG_TOGGLE_SESSION="/data/local/tmp/usb_debug_session_${CURRENT_BOOT_ID}"
    
    if echo "$usb_state" | grep -q "rndis"; then
        # Check if tethering is actually working
        if ! ip addr show rndis0 2>/dev/null | grep -q "inet "; then
            echo "Post-boot: RNDIS has no IP" | log -t $log_tag
            
            # Check if USB debug toggle was already done THIS BOOT
            if [ -f "$USB_DEBUG_TOGGLE_SESSION" ]; then
                echo "Post-boot: USB debug toggle already done this boot, performing standard reset..." | log -t $log_tag
                
                # Standard tethering reset
                settings put global usb_tethering_enabled 0 2>/dev/null
                service call connectivity 31 i32 0 2>/dev/null
                svc usb setFunctions mtp 2>/dev/null
                sleep 5
                
                # Re-enable everything
                svc usb setFunctions none 2>/dev/null
                sleep 2
                settings put global usb_tethering_enabled 1 2>/dev/null
                svc usb setFunctions rndis 2>/dev/null
                sleep 3
                service call connectivity 30 i32 0 2>/dev/null
                
                echo "Post-boot: Standard tethering reset completed" | log -t $log_tag
            else
                echo "Post-boot: USB debug toggle not done this boot, performing it now..." | log -t $log_tag
                
                # Create session flag and do toggle
                touch "$USB_DEBUG_TOGGLE_SESSION"
                echo "Post-boot Boot ID: $CURRENT_BOOT_ID" > "$USB_DEBUG_TOGGLE_SESSION"
                
                usb_debug_enabled=$(settings get global adb_enabled 2>/dev/null)
                if [ "$usb_debug_enabled" = "1" ]; then
                    # Disable USB debugging for 5 seconds
                    settings put global adb_enabled 0 2>/dev/null
                    setprop ctl.stop adbd
                    echo "Post-boot: USB debugging disabled" | log -t $log_tag
                    
                    sleep 5
                    
                    # Re-enable USB debugging
                    settings put global adb_enabled 1 2>/dev/null
                    setprop ctl.start adbd
                    echo "Post-boot: USB debugging re-enabled" | log -t $log_tag
                    
                    sleep 10
                fi
            fi
        else
            echo "Post-boot: Tethering is working properly" | log -t $log_tag
        fi
    fi
fi