#!/system/bin/sh

# Auto USB Tether + Charger Cutoff Service
MODDIR=${0%/*}
TETHER_TOGGLE="/sdcard/usb_tether_toggle.txt"
CHARGER_TOGGLE="/sdcard/auto_charger_cutoff.txt"
log_tag="usb_tether_charger"

# Wait for system to be ready
sleep 15

# Create toggle files if they don't exist
[ ! -f "$TETHER_TOGGLE" ] && echo "1" > "$TETHER_TOGGLE"
[ ! -f "$CHARGER_TOGGLE" ] && echo "0" > "$CHARGER_TOGGLE"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if required commands exist
if ! command_exists svc; then
    echo "svc command not found, USB tethering will not work" | log -t $log_tag
fi

# Function to kill existing instances
kill_existing() {
    local pids=$(pgrep -f "usb_tether_charger")
    if [ -n "$pids" ]; then
        echo "Killing existing instances: $pids" | log -t $log_tag
        kill $pids 2>/dev/null
        sleep 2
    fi
}

# Kill any existing instances to prevent duplicates
kill_existing

# Cleanup old session files (keep only current boot session)
cleanup_old_sessions() {
    local current_session="usb_debug_session_${CURRENT_BOOT_ID}"
    local cleanup_count=0
    
    for old_file in /data/local/tmp/usb_debug_session_*; do
        if [ -f "$old_file" ] && ! echo "$old_file" | grep -q "$current_session"; then
            rm "$old_file" 2>/dev/null
            cleanup_count=$((cleanup_count + 1))
        fi
    done
    
    if [ $cleanup_count -gt 0 ]; then
        echo "Cleaned up $cleanup_count old session files" | log -t $log_tag
    fi
}

cleanup_old_sessions

# Main service loop
(
echo "Auto USB Tether + Charger service started" | log -t $log_tag

# Wait for network services to be ready
wait_for_network() {
    local timeout=60
    local count=0
    
    while [ $count -lt $timeout ]; do
        if getprop sys.boot_completed | grep -q "1"; then
            echo "Boot completed detected" | log -t $log_tag
            sleep 5  # Additional wait for network stack
            break
        fi
        sleep 2
        count=$((count + 2))
    done
}

wait_for_network

# Enhanced USB initialization sequence
if command_exists svc; then
    echo "Starting USB tethering initialization..." | log -t $log_tag
    
    # Check if USB debugging toggle has been done THIS BOOT SESSION
    USB_DEBUG_TOGGLE_FLAG="/data/local/tmp/usb_debug_toggled_$(getprop ro.boot.serialno)_$(date +%Y%m%d)"
    CURRENT_BOOT_ID=$(cat /proc/sys/kernel/random/boot_id 2>/dev/null | cut -c1-8)
    USB_DEBUG_TOGGLE_SESSION="/data/local/tmp/usb_debug_session_${CURRENT_BOOT_ID}"
    
    # Step 1: Check and perform USB debugging toggle every boot (but only once per boot)
    usb_debugging=$(settings get global adb_enabled 2>/dev/null)
    if [ "$usb_debugging" = "1" ] && [ ! -f "$USB_DEBUG_TOGGLE_SESSION" ]; then
        echo "Boot session: USB debugging enabled, performing one-time toggle for this boot..." | log -t $log_tag
        
        # Create session flag file to mark that toggle has been done THIS BOOT
        touch "$USB_DEBUG_TOGGLE_SESSION"
        echo "Boot ID: $CURRENT_BOOT_ID" > "$USB_DEBUG_TOGGLE_SESSION"
        
        # Disable USB debugging
        settings put global adb_enabled 0 2>/dev/null
        setprop ctl.stop adbd
        echo "USB debugging disabled for refresh..." | log -t $log_tag
        sleep 5
        
        # Re-enable USB debugging
        settings put global adb_enabled 1 2>/dev/null
        setprop ctl.start adbd
        echo "USB debugging re-enabled - toggle completed for this boot session" | log -t $log_tag
        sleep 3
    elif [ -f "$USB_DEBUG_TOGGLE_SESSION" ]; then
        echo "USB debugging toggle already performed this boot session, skipping..." | log -t $log_tag
    elif [ "$usb_debugging" != "1" ]; then
        echo "USB debugging not enabled, skipping toggle..." | log -t $log_tag
    fi
    
    # Step 2: Reset USB completely
    svc usb setFunctions none 2>/dev/null
    sleep 3
    
    # Step 3: Enable USB tethering service first
    settings put global tether_supported_types 7 2>/dev/null
    
    # Step 4: Set USB to rndis
    svc usb setFunctions rndis 2>/dev/null
    sleep 3
    
    # Step 5: Enable tethering via settings
    settings put global usb_tethering_enabled 1 2>/dev/null
    
    # Step 6: Force enable via service calls
    service call connectivity 30 i32 0 2>/dev/null
    
    echo "USB tethering initialization completed" | log -t $log_tag
fi

while true; do
    # Read toggle states with error handling
    toggle=$(cat "$TETHER_TOGGLE" 2>/dev/null || echo "1")
    charger_toggle=$(cat "$CHARGER_TOGGLE" 2>/dev/null || echo "0")
    
    # Validate toggle values
    case "$toggle" in
        0|1) ;;
        *) toggle="1" ;;
    esac
    
    case "$charger_toggle" in
        0|1) ;;
        *) charger_toggle="0" ;;
    esac

    # USB Tethering logic - simplified monitoring (no more USB debug toggle during runtime)
    if [ "$toggle" = "1" ] && command_exists svc; then
        usb_state=$(getprop sys.usb.state 2>/dev/null || echo "")
        
        if echo "$usb_state" | grep -q "rndis"; then
            # Simple connectivity check
            has_internet=false
            
            # Check if RNDIS interface has IP
            if command_exists ip && ip addr show rndis0 2>/dev/null | grep -q "inet "; then
                rndis_ip=$(ip addr show rndis0 2>/dev/null | grep "inet " | awk '{print $2}' | head -1)
                echo "RNDIS IP detected: $rndis_ip" | log -t $log_tag
                
                # Quick internet check
                if ip route show 2>/dev/null | grep -q "default" && nslookup google.com 2>/dev/null | grep -q "Address"; then
                    has_internet=true
                    echo "Internet connectivity confirmed" | log -t $log_tag
                fi
            fi
            
            # If no internet, do standard reset (no USB debug toggle anymore)
            if [ "$has_internet" = "false" ]; then
                echo "No internet connectivity, performing standard tethering reset..." | log -t $log_tag
                
                # Standard reset sequence
                settings put global usb_tethering_enabled 0 2>/dev/null
                service call connectivity 31 i32 0 2>/dev/null
                svc usb setFunctions none 2>/dev/null
                sleep 3
                
                # Re-enable with full sequence
                settings put global usb_tethering_enabled 1 2>/dev/null
                svc usb setFunctions rndis 2>/dev/null
                sleep 2
                service call connectivity 30 i32 0 2>/dev/null
                
                echo "Standard tethering reset completed" | log -t $log_tag
            fi
            
            sleep 15
        elif echo "$usb_state" | grep -q "configured"; then
            echo "USB configured, activating RNDIS..." | log -t $log_tag
            
            # Enable tethering with complete sequence
            settings put global usb_tethering_enabled 1 2>/dev/null
            svc usb setFunctions rndis 2>/dev/null
            sleep 2
            service call connectivity 30 i32 0 2>/dev/null
            sleep 5
        else
            # USB not configured, wait more
            echo "USB not ready, current state: $usb_state" | log -t $log_tag
            sleep 10
        fi
    fi

    # Charger auto cut with custom threshold
    if [ "$charger_toggle" = "1" ]; then
        # Try different battery paths
        battery_path=""
        for path in /sys/class/power_supply/battery /sys/class/power_supply/BAT0 /sys/class/power_supply/BAT1; do
            if [ -f "$path/capacity" ]; then
                battery_path="$path"
                break
            fi
        done
        
        if [ -n "$battery_path" ]; then
            capacity=$(cat "$battery_path/capacity" 2>/dev/null || echo "0")
            status=$(cat "$battery_path/status" 2>/dev/null || echo "Unknown")
            
            # Validate capacity is numeric
            case "$capacity" in
                ''|*[!0-9]*) capacity=0 ;;
            esac
            
            if [ "$capacity" -ge 98 ] && [ "$status" = "Charging" ]; then
                echo "Cutting charger (battery $capacity%)" | log -t $log_tag
                echo 0 > "$battery_path/charging_enabled" 2>/dev/null
            elif [ "$capacity" -le 72 ] && [ "$status" != "Charging" ]; then
                echo "Re-enabling charger (battery $capacity%)" | log -t $log_tag
                echo 1 > "$battery_path/charging_enabled" 2>/dev/null
            fi
        fi
    fi

    sleep 5
done
) &