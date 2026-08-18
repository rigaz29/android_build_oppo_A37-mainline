#!/usr/bin/env bash
# Panen data hardware dari OPPO A37f lewat adb.
#
# Menghasilkan berkas yang jadi dasar HARDWARE-A37f.md. Semua perintahnya
# hanya membaca, tidak ada yang menulis ke perangkat, dan tidak butuh root.
#
#   ./harvest-device-info.sh > harvest-$(date +%F).txt
#
set -u

h() { printf '\n===== %s =====\n' "$1"; }

h "identitas"
adb shell 'getprop ro.product.device; getprop ro.product.model; getprop ro.board.platform
           getprop ro.build.version.release; getprop ro.lineage.version; uname -r'

h "board-id / msm-id (dipakai lk2nd untuk mencocokkan perangkat)"
adb shell 'od -A n -t x1 /proc/device-tree/qcom,board-id'
adb shell 'od -A n -t x1 /proc/device-tree/qcom,msm-id'
adb shell 'cat /proc/device-tree/model; echo; cat /proc/device-tree/compatible; echo'

h "panel yang terpasang"
adb shell 'cat /sys/class/graphics/fb0/msm_fb_panel_info' 2>/dev/null | grep -E 'panel_name|xres|yres'

h "layar"
adb shell 'wm size; wm density'

h "i2c: chip yang BENAR-BENAR ada (driver ter-bind)"
adb shell 'for d in /sys/bus/i2c/devices/*-*; do
             drv=$(readlink $d/driver 2>/dev/null | sed "s|.*/||")
             [ -n "$drv" ] && echo "$(basename $d)  name=$(cat $d/name)  driver=$drv"
           done'

h "i2c: node DT tanpa chip (JANGAN ditulis ke DTS mainline)"
adb shell 'for d in /sys/bus/i2c/devices/*-*; do
             [ -e $d/driver ] || echo "$(basename $d)  name=$(cat $d/name 2>/dev/null)"
           done'

h "input"
adb shell 'grep -E "^N: Name" /proc/bus/input/devices'

h "leds / vibrator"
adb shell 'ls /sys/class/leds/; ls /sys/class/timed_output/ 2>/dev/null'

h "baterai"
adb shell 'grep -E "TECHNOLOGY|MODEL_NAME|VOLTAGE_MAX|CHARGE_FULL" /sys/class/power_supply/battery/uevent'

h "gpu"
adb shell 'getprop ro.hardware.egl; getprop ro.opengles.version'

h "memori dan penyimpanan"
adb shell 'free -m | head -2; echo "eMMC: $(( $(cat /sys/class/block/mmcblk0/size) / 2048 )) MB"'

h "partisi + ukuran"
adb shell 'for l in /dev/block/bootdevice/by-name/*; do
             n=$(readlink $l | sed "s|.*/||")
             sz=$(cat /sys/class/block/$n/size 2>/dev/null)
             [ -n "$sz" ] && printf "%-16s %-14s %6d MB\n" "$(basename $l)" "$n" "$((sz/2048))"
           done | sort'

h "radio"
adb shell 'getprop | grep -iE "wlan.driver.version|wlan.firmware.version|bluetooth.soc|multisim.config"'
