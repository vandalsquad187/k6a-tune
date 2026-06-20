#!/system/bin/sh
MODDIR=${0%/*}
mkdir -p "$MODDIR/run" "$MODDIR/config"
chmod 755 "$MODDIR/bin/k6a-controller" 2>/dev/null
chmod 755 "$MODDIR/bin/k6a-lib.sh" 2>/dev/null
