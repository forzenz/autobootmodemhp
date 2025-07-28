#!/system/bin/sh

# Magisk Module Installer Script
# Auto USB Tether + Fix Boot + Charger Cutoff

##########################################################################################
# Config Flags
##########################################################################################

# Set to true if you do *NOT* want Magisk to mount
# any files in this module by default. Most modules would want to leave this as false.
SKIPMOUNT=false

# Set to true if you need to load system.prop
PROPFILE=false

# Set to true if you need post-fs-data script
POSTFSDATA=true

# Set to true if you need late_start service script
LATESTARTSERVICE=true

##########################################################################################
# Replace list
##########################################################################################

# List all directories you want to directly replace in the system
# Check the documentations for more info why you would need this

# Construct your list in the following format
# This is an example
REPLACE_EXAMPLE="
/system/app/Youtube
/system/priv-app/SystemUI
/system/priv-app/Settings
/system/framework
"

# Construct your own list here
REPLACE=""

##########################################################################################
# Function Callbacks
##########################################################################################

# The following functions will be called by the installation framework.
# You do not have the ability to modify update-binary, the only way you can customize
# installation is through implementing these functions.
#
# When running your callbacks, the installation framework will make sure the Magisk
# internal busybox path is *PREPENDED* to PATH, so all common commands shall exist.
# Also, it will make sure /data, /system, and /vendor is properly mounted.

##########################################################################################
# The installation framework will export some variables and functions.
# You should use these variables and functions for installation.
#
# ! DO NOT use any Magisk internal paths as those are NOT public API.
# ! DO NOT use other functions in util_functions.sh as they are NOT public API.
# ! Non public APIs are not guranteed to maintain compatibility between releases.
#
# Available variables:
#
# MAGISK_VER (string): the version string of currently installed Magisk
# MAGISK_VER_CODE (int): the version code of currently installed Magisk
# BOOTMODE (bool): true if the module is currently being installed in Magisk Manager
# MODPATH (path): the path where your module files should be installed
# TMPDIR (path): a place where you can temporarily store files
# ZIPFILE (path): your module's installation zip
# ARCH (string): the architecture of the device. Value is either arm, arm64, x86, or x64
# IS64BIT (bool): true if $ARCH is either arm64 or x64
#
# Available functions:
#
# ui_print <msg>
#     print <msg> to console
#     Avoid using 'echo' as it will not display in custom recovery's console
#
# abort <msg>
#     print error message <msg> to console and terminate installation
#     Avoid using 'exit' as it will skip the termination cleanup steps
#
# set_perm <target> <owner> <group> <permission> [context]
#     if [context] is empty, it will default to "u:object_r:system_file:s0"
#     this function is a shorthand for the following commands
#       chown owner.group target
#       chmod permission target
#       chcon context target
#
# set_perm_recursive <directory> <owner> <group> <dirpermission> <filepermission> [context]
#     if [context] is empty, it will default to "u:object_r:system_file:s0"
#     for all files in <directory>, it will call:
#       set_perm file owner group filepermission context
#     for all directories in <directory> (including itself), it will call:
#       set_perm dir owner group dirpermission context
#

##########################################################################################
# If you need boot scripts, DO NOT use general boot scripts (service.d/post-fs-data.d)
# ONLY use module scripts as it respects the module status (remove/disable) and is
# guaranteed to maintain the same behavior in future Magisk releases.
# Enable boot scripts by setting the flags in the config section above.
##########################################################################################

# Set what you want to display when installing your module

print_modname() {
  ui_print "*******************************"
  ui_print "  Auto USB Tether + Charger    "
  ui_print "         Cutoff v1.4           "
  ui_print "*******************************"
}

# Copy/extract your module files into $MODPATH in on_install.

on_install() {
  ui_print "- Extracting module files"
  unzip -o "$ZIPFILE" 'service.sh' -d $MODPATH >&2
  unzip -o "$ZIPFILE" 'post-fs-data.sh' -d $MODPATH >&2
  unzip -o "$ZIPFILE" 'post-boot.sh' -d $MODPATH >&2
  
  ui_print "- Setting permissions"
  set_perm_recursive $MODPATH 0 0 0755 0644
  set_perm $MODPATH/service.sh 0 0 0755
  set_perm $MODPATH/post-fs-data.sh 0 0 0755
  set_perm $MODPATH/post-boot.sh 0 0 0755
  
  # Create delayed execution script
  cat > $MODPATH/service.sh << 'EOF'
#!/system/bin/sh
# Main service
MODDIR=${0%/*}
$MODDIR/service-main.sh &
# Delayed post-boot check
(sleep 60; $MODDIR/post-boot.sh) &
EOF
  
  # Rename main service script
  if [ -f $MODPATH/service-main.sh ]; then
    rm $MODPATH/service-main.sh
  fi
  
  ui_print "- Creating toggle files and utility scripts"
  mkdir -p /sdcard
  [ ! -f /sdcard/usb_tether_toggle.txt ] && echo "1" > /sdcard/usb_tether_toggle.txt
  [ ! -f /sdcard/auto_charger_cutoff.txt ] && echo "0" > /sdcard/auto_charger_cutoff.txt
  
  # Create utility scripts
  cat > /sdcard/reset_usb_debug_flag.sh << 'RESETEOF'
#!/system/bin/sh
echo "=== USB Debug Toggle Session Reset ==="
CURRENT_BOOT_ID=$(cat /proc/sys/kernel/random/boot_id 2>/dev/null | cut -c1-8)
USB_DEBUG_TOGGLE_SESSION="/data/local/tmp/usb_debug_session_${CURRENT_BOOT_ID}"
if [ -f "$USB_DEBUG_TOGGLE_SESSION" ]; then
    rm "$USB_DEBUG_TOGGLE_SESSION"
    echo "✓ Session flag removed. Toggle will run again when service restarts."
else
    echo "! Session flag not found. Toggle will run when service starts."
fi
# Cleanup old sessions
for old_file in /data/local/tmp/usb_debug_session_*; do
    [ -f "$old_file" ] && rm "$old_file" 2>/dev/null
done
echo "✓ All session files cleaned"
RESETEOF
  
  chmod 755 /sdcard/reset_usb_debug_flag.sh
  
  ui_print "- Installation complete"
  ui_print ""
  ui_print "Toggle files created in /sdcard/:"
  ui_print "  usb_tether_toggle.txt (1=on, 0=off)"
  ui_print "  auto_charger_cutoff.txt (1=on, 0=off)"
  ui_print "  reset_usb_debug_flag.sh (reset session flag)"
  ui_print ""
  ui_print "USB Debug Toggle Feature:"
  ui_print "- Runs EVERY RESTART if USB debugging is enabled"
  ui_print "- But only ONCE per boot session"
  ui_print "- USB debugging will be toggled off for 5 seconds"
  ui_print "  then back on to refresh the connection"
  ui_print "- After toggle, cable unplug/plug works normally"
  ui_print ""
  ui_print "To force toggle again THIS BOOT:"
  ui_print "  sh /sdcard/reset_usb_debug_flag.sh"
  ui_print ""
  ui_print "Session files auto-cleanup on each boot"
}

# Only some special files require specific permissions
# This function will be called after on_install is done
# The default permissions should be good enough for most cases

set_permissions() {
  # The following is the default rule, DO NOT remove
  set_perm_recursive $MODPATH 0 0 0755 0644

  # Here are some examples:
  # set_perm_recursive  $MODPATH/system/lib       0     0       0755      0644
  # set_perm  $MODPATH/system/bin/app_process32   0     2000    0755      u:object_r:zygote_exec:s0
  # set_perm  $MODPATH/system/bin/dex2oat         0     2000    0755      u:object_r:dex2oat_exec:s0
  # set_perm  $MODPATH/system/lib/libart.so       0     0       0644
  
  # Set executable permissions for scripts
  set_perm $MODPATH/service.sh 0 0 0755
  set_perm $MODPATH/post-fs-data.sh 0 0 0755
}

# You can add more functions to assist your custom script code