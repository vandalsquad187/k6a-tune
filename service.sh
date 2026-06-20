#!/system/bin/sh
# k6a-tune service.sh  v1.1 — mit Watchdog-Restart
# ─────────────────────────────────────────────────────────────────────────────

MODDIR=${0%/*}
CTRL="$MODDIR/bin/k6a-controller"
LOG="$MODDIR/config/service.log"
CONF="$MODDIR/config/settings.conf"
LOCKFILE="$MODDIR/run/service.lock"

_log() { printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$1" >> "$LOG"; }

_rotate_log() {
    [ -f "$LOG" ] || return
    local size; size=$(wc -c < "$LOG" 2>/dev/null) || return
    [ "$size" -gt 204800 ] && mv "$LOG" "${LOG}.old"
}

mkdir -p "$MODDIR/run" "$MODDIR/config"
_rotate_log

BOOT_DELAY=$(grep "^boot_delay=" "$CONF" 2>/dev/null | cut -d= -f2)
case "$BOOT_DELAY" in ''|*[!0-9]*) BOOT_DELAY=6 ;; esac
[ "$BOOT_DELAY" -lt 3 ] && BOOT_DELAY=3
[ "$BOOT_DELAY" -gt 60 ] && BOOT_DELAY=60

until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 3; done

_ready_wait=0
until [ -d /sys/class/thermal ] && [ -d /sys/devices/system/cpu/cpufreq ]; do
    sleep 1; _ready_wait=$(( _ready_wait + 1 ))
    [ "$_ready_wait" -ge 30 ] && break
done
[ "$_ready_wait" -gt 0 ] && _log "Ready wait: ${_ready_wait}s"

sleep "$BOOT_DELAY"
_rotate_log

if [ -f "$LOCKFILE" ]; then
    _old_pid=$(cat "$LOCKFILE" 2>/dev/null)
    if [ -n "$_old_pid" ] && [ -d "/proc/$_old_pid" ]; then
        _log "Already running (PID $_old_pid) — exit"; exit 0
    fi
    rm -f "$LOCKFILE"
fi
echo $$ > "$LOCKFILE"
_cleanup() { rm -f "$LOCKFILE"; }
trap '_cleanup; exit' EXIT INT TERM

chmod 755 "$CTRL" 2>/dev/null
[ -f "$CTRL" ] || { _log "k6a-controller not found"; exit 1; }

_log "Starting k6a-controller"
_uptime_s() { cut -d. -f1 /proc/uptime 2>/dev/null || date +%s; }

_backoff=3
_crash_count=0
_crash_window=$(_uptime_s)

while true; do
    nice -n -5 sh "$CTRL" "$MODDIR"
    _exit=$?
    _now=$(_uptime_s)

    case "$_exit" in
        0)   _log "Controller exit 0 — stop"; exit 0 ;;
        143) _log "Controller SIGTERM — restart"; sleep 2; _backoff=3; _rotate_log; continue ;;
    esac

    if [ $(( _now - _crash_window )) -lt 60 ]; then
        _crash_count=$(( _crash_count + 1 ))
        if [ "$_crash_count" -gt 10 ]; then
            _log "Crash storm (${_crash_count}x/60s) — giving up"; exit 1
        fi
        [ "$_backoff" -lt 30 ] && _backoff=$(( _backoff * 2 ))
    else
        _crash_count=1; _backoff=3; _crash_window=$_now
    fi

    _log "Controller exit $_exit — restart in ${_backoff}s (crash #${_crash_count})"
    _rotate_log; sleep "$_backoff"
done
