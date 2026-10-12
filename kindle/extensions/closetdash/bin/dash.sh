#!/bin/sh
# Closet Dash - main program (started by start.sh from KUAL).
# Pauses the Kindle's reading interface, shows the weather picture and keeps it current.
# Exit: tap the screen twice, or restart the Kindle (it then comes back as a normal Kindle).

trap '' TERM HUP   # survive the reading interface being stopped (same process group)

DIR="$(cd "$(dirname "$0")/.." && pwd)"
. "$DIR/bin/settings.sh"
RUN="/tmp/closetdash"
LOG="$DIR/dash-log.txt"
PIDFILE="$RUN/dash.pid"
CACERT="$DIR/cacert.pem"
UI_JOBS="framework lab126_gui"
TICK=5
WARN_SHOWN=""
WPID=""

mkdir -p "$RUN"
[ -f "$LOG" ] && [ "$(wc -l < "$LOG")" -gt 2000 ] && tail -n 1000 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
exec >> "$LOG" 2>&1

log() {
	echo "$(date '+%m-%d %H:%M:%S') $*"
}

sys() {   # anything that changes the Kindle; CLOSETDASH_DRY=1 only logs it (PC testing)
	if [ -n "$CLOSETDASH_DRY" ]; then log "DRY: $*" >> "$LOG"; else "$@"; fi
}

num() {   # "0530" -> 530 (no octal surprises)
	echo "$1" | sed 's/^0*//; s/^$/0/'
}

state() {   # state NAME [DEFAULT]
	cat "$RUN/$1" 2>/dev/null || echo "${2:-}"
}

now_vars() {
	if [ -n "$FAKE_NOW" ]; then
		set -- $(date -d "$FAKE_NOW" '+%s %Y-%m-%d %H%M %S')
	else
		set -- $(date '+%s %Y-%m-%d %H%M %S')
	fi
	EPOCH=$1
	TODAY=$2
	HHMM=$3
	SECS=$4
}

minutes() {   # "0530" -> 330 (minutes since midnight)
	echo $(( $(num "${1%??}") * 60 + $(num "${1#??}") ))
}

battery() {
	lipc-get-prop com.lab126.powerd battLevel 2>/dev/null
}

# ------------------------------------------------------------------ reading interface
ui_stop() {
	: > "$RUN/stopped_jobs"
	for j in $UI_JOBS; do
		if initctl status "$j" 2>/dev/null | grep -q running; then
			sys stop "$j" > /dev/null 2>&1
			echo "$j" >> "$RUN/stopped_jobs"
			log "stopped $j"
		fi
	done
}

ui_start() {
	for j in $(state stopped_jobs); do
		sys start "$j" > /dev/null 2>&1
		log "started $j"
	done
	rm -f "$RUN/stopped_jobs"
}

# ------------------------------------------------------------------ Wi-Fi, clock, downloads
wifi_up() {
	[ "$(lipc-get-prop com.lab126.wifid cmState 2>/dev/null)" = "CONNECTED" ] && return 0
	sys lipc-set-prop com.lab126.cmd wirelessEnable 1
	i=0
	while [ $i -lt 30 ]; do
		sleep 2
		[ "$(lipc-get-prop com.lab126.wifid cmState 2>/dev/null)" = "CONNECTED" ] && return 0
		i=$((i + 1))
	done
	return 1
}

wifi_down() {
	[ "$WIFI_OFF_BETWEEN" = "1" ] && sys lipc-set-prop com.lab126.cmd wirelessEnable 0
}

get() {   # get URL FILE: verified download first, then unverified (-k); sets METHOD
	rm -f "$2"
	if curl -f -sS --max-time 30 --cacert "$CACERT" -o "$2" "$1" && [ -s "$2" ]; then
		METHOD="verified"
		return 0
	fi
	if curl -f -k -sS --max-time 30 -o "$2" "$1" && [ -s "$2" ]; then
		METHOD="unverified"
		return 0
	fi
	return 1
}

set_clock() {   # fix the Kindle clock from the web server's Date header if it is >2 min off
	d="$(curl -k -sSI --max-time 20 "$BASE/status.txt" 2>/dev/null | sed -n 's/^[Dd]ate: *//p' | tr -d '\r')"
	set -- $d   # Sun, 12 Oct 2026 01:32:59 GMT
	[ $# -ge 5 ] || return
	case "$3" in
		Jan) m=01 ;; Feb) m=02 ;; Mar) m=03 ;; Apr) m=04 ;; May) m=05 ;; Jun) m=06 ;;
		Jul) m=07 ;; Aug) m=08 ;; Sep) m=09 ;; Oct) m=10 ;; Nov) m=11 ;; Dec) m=12 ;;
		*) return ;;
	esac
	stamp="$4-$m-$2 $5"
	server=$(date -u -d "$stamp" +%s 2>/dev/null) || return
	diff=$((server - $(date +%s)))
	[ $diff -lt 0 ] && diff=$((-diff))
	if [ $diff -gt 120 ]; then
		sys date -u -s "$stamp" > /dev/null
		sys hwclock -u -w 2>/dev/null
		log "clock corrected by ${diff}s"
	fi
}

# ------------------------------------------------------------------ schedule
last_slot_epoch() {   # epoch of the latest scheduled time already reached today (0 = none yet)
	now_min=$(minutes "$HHMM")
	best=0
	for t in $FETCH_TIMES; do
		t_min=$(minutes "$t")
		if [ "$now_min" -ge "$t_min" ]; then
			best=$(( EPOCH - (now_min - t_min) * 60 - $(num "$SECS") ))
		fi
	done
	echo "$best"
}

image_ok() {   # is the picture on screen for the right day?
	s="$(state shown_for)"
	[ -n "$s" ] || return 1
	if [ "$(num "$HHMM")" -lt "$(num "$TOMORROW_FROM")" ]; then
		[ "$s" = "$TODAY" ]
	else
		awk -v a="$s" -v b="$TODAY" 'BEGIN { exit !(a > b) }'
	fi
}

due() {
	fails=$(state fails 0)
	if [ "$fails" -gt 0 ]; then
		wait=$RETRY_MIN
		[ "$fails" -ge "$RETRY_FAST_TRIES" ] && wait=$RETRY_SLOW_MIN
		[ $((EPOCH - $(state last_try 0))) -ge $((wait * 60)) ]
		return
	fi
	slot=$(last_slot_epoch)
	[ "$slot" -gt 0 ] && [ "$(state last_ok 0)" -lt "$slot" ] && return 0
	image_ok || return 0
	return 1
}

fail() {
	f=$(( $(state fails 0) + 1 ))
	echo "$f" > "$RUN/fails"
	log "FAIL ($f): $1"
	wifi_down
}

fetch() {
	echo "$EPOCH" > "$RUN/last_try"
	wifi_up || { fail "no Wi-Fi connection"; return 1; }
	set_clock
	now_vars
	get "$BASE/status.txt" "$RUN/status.txt" || { fail "could not download status.txt"; return 1; }
	st_today="$(sed -n 's/^today=//p' "$RUN/status.txt")"
	st_tom="$(sed -n 's/^tomorrow=//p' "$RUN/status.txt")"
	st_built="$(sed -n 's/^built=//p' "$RUN/status.txt")"

	pick=""
	if [ "$(num "$HHMM")" -ge "$(num "$TOMORROW_FROM")" ]; then
		[ "$st_today" = "$TODAY" ] && pick="tomorrow" && cover="$st_tom"
	elif [ "$st_today" = "$TODAY" ]; then
		pick="today" && cover="$st_today"
	elif [ "$st_tom" = "$TODAY" ]; then
		pick="tomorrow" && cover="$st_tom"
	fi
	[ -n "$pick" ] || { fail "no picture for the right day yet (server today=$st_today)"; return 1; }

	get "$BASE/$pick.png" "$RUN/new.png" || { fail "could not download $pick.png"; return 1; }
	[ "$(dd if="$RUN/new.png" bs=1 skip=1 count=3 2>/dev/null)" = "PNG" ] || { fail "$pick.png is not a picture"; return 1; }
	mv "$RUN/new.png" "$RUN/current.png"
	echo "$cover" > "$RUN/shown_for"
	echo "$EPOCH" > "$RUN/last_ok"
	date '+%a %H:%M' > "$RUN/last_ok_text"
	echo 0 > "$RUN/fails"
	log "OK $pick.png for $cover ($METHOD; built $st_built; battery $(battery)%)"
	wifi_down
	WARN_SHOWN="(redraw)"
	return 0
}

# ------------------------------------------------------------------ screen
warning_text() {   # warning lines separated by '|' (each kept under ~44 characters)
	w=""
	if [ "$(state fails 0)" -ge "$RETRY_FAST_TRIES" ]; then
		if [ -f "$RUN/current.png" ] && ! image_ok; then
			w="NOT UPDATED - forecast is for $(state shown_for | cut -c6-)"
		elif [ -f "$RUN/last_ok_text" ]; then
			w="Update failing since $(state last_ok_text) - check Wi-Fi"
		else
			w="No update yet - check Wi-Fi"
		fi
	fi
	b="$(battery)"
	if [ -n "$b" ] && [ "$b" -lt "$LOW_BATTERY" ] 2>/dev/null; then
		w="$w${w:+|}Battery $b% - please charge"
	fi
	echo "$w"
}

show() {   # full redraw: picture (or a message) plus any warning lines
	w="$(warning_text)"
	if [ -f "$RUN/current.png" ]; then
		sys eips -f -g "$RUN/current.png" > /dev/null 2>&1
	else
		sys eips -c > /dev/null 2>&1
		sys eips 1 3 "Waiting for the first download..." > /dev/null 2>&1
	fi
	if [ -n "$w" ]; then
		row=0
		rest="$w"
		while [ -n "$rest" ]; do
			line="${rest%%|*}"
			[ "$line" = "$rest" ] && rest="" || rest="${rest#*|}"
			sys eips 0 $row "$line" > /dev/null 2>&1
			row=$((row + 1))
		done
		sys eips 0 $row "Tap the screen twice to exit." > /dev/null 2>&1
	fi
	WARN_SHOWN="$w"
}

light() {
	n=$(num "$HHMM")
	want=0
	if [ "$n" -ge "$(num "$LIGHT_ON")" ] && [ "$n" -lt "$(num "$LIGHT_OFF")" ]; then
		want=$LIGHT_LEVEL
	fi
	[ "$want" = "$(state light)" ] && return
	sys lipc-set-prop com.lab126.powerd flIntensity "$want"
	echo "$want" > "$RUN/light"
	log "front light $want"
}

# ------------------------------------------------------------------ taps (exit gesture)
find_touch() {
	awk '/^N:/ { name = $0 }
	     /^H:/ { if (name ~ /zforce|[Tt]ouch|cyttsp|mxt|[Ss]creen/ && match($0, /event[0-9]+/)) {
	                 print "/dev/input/" substr($0, RSTART, RLENGTH); exit } }' /proc/bus/input/devices 2>/dev/null
}

watch_taps() {   # 1st tap -> refresh + prompt; 2nd tap within 10 s -> exit
	while :; do
		dd if="$TOUCH" of=/dev/null bs=16 count=1 2>/dev/null || { sleep 10; continue; }
		touch "$RUN/tap1"
		sleep 1
		rm -f "$RUN/tap2"
		dd if="$TOUCH" of="$RUN/tap2" bs=16 count=1 2>/dev/null &
		p=$!
		i=0
		while [ $i -lt 10 ] && [ ! -s "$RUN/tap2" ]; do
			sleep 1
			i=$((i + 1))
		done
		kill -9 $p 2>/dev/null
		if [ -s "$RUN/tap2" ]; then
			touch "$RUN/exit"
			return
		fi
	done
}

# ------------------------------------------------------------------ start / stop
cleanup() {
	trap '' TERM INT HUP
	[ -n "$WPID" ] && kill -9 "$WPID" 2>/dev/null
	sys lipc-set-prop com.lab126.powerd preventScreenSaver 0
	sys lipc-set-prop com.lab126.powerd flIntensity "$(state light_before 5)"
	sys lipc-set-prop com.lab126.cmd wirelessEnable 1
	ui_start
	rm -f "$PIDFILE" "$RUN/exit" "$RUN/tap1" "$RUN/tap2"
	log "stopped - back to normal Kindle"
	exit 0
}

if [ -f "$PIDFILE" ] && kill -0 "$(state dash.pid)" 2>/dev/null; then
	log "already running"
	exit 0
fi
echo $$ > "$PIDFILE"
rm -f "$RUN/exit" "$RUN/tap1" "$RUN/tap2" "$RUN/light" "$RUN/fails"
log "=== Closet Dash v0.2 starting (battery $(battery)%)"
log "ui jobs: $(initctl list 2>/dev/null | grep -e framework -e lab126_gui -e pillow | tr '\n' ';')"
lipc-get-prop com.lab126.powerd flIntensity > "$RUN/light_before" 2>/dev/null

sleep 3   # let KUAL close
ui_stop
trap cleanup TERM INT
sys lipc-set-prop com.lab126.powerd preventScreenSaver 1

TOUCH="${CLOSETDASH_TOUCH:-$(find_touch)}"
log "touch device: ${TOUCH:-none found (exit by restarting the Kindle)}"
if [ -n "$TOUCH" ]; then
	watch_taps &
	WPID=$!
fi

sys eips -c > /dev/null 2>&1
sys eips 1 3 "Closet Dash is starting..." > /dev/null 2>&1
sys eips 1 5 "To exit later: tap the screen twice." > /dev/null 2>&1

FORCE=1
while :; do
	now_vars
	[ -f "$RUN/exit" ] && cleanup
	light
	if [ -f "$RUN/tap1" ]; then   # keep the prompt up while the watcher waits for a 2nd tap
		rm -f "$RUN/tap1"
		sys eips 0 0 "Tap again within 10 s to exit Closet Dash." > /dev/null 2>&1
		i=0
		while [ $i -lt 12 ] && [ ! -f "$RUN/exit" ]; do
			sleep 1
			i=$((i + 1))
		done
		[ -f "$RUN/exit" ] && cleanup
		FORCE=1
		WARN_SHOWN="(redraw)"
	fi
	if [ -n "$FORCE" ] || due; then
		FORCE=""
		fetch
	fi
	[ "$(warning_text)" != "$WARN_SHOWN" ] && show
	[ -n "$CLOSETDASH_ONCE" ] && cleanup
	sleep $TICK
done
