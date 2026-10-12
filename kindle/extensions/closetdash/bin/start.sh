#!/bin/sh
# Launched from KUAL: start dash.sh detached, so it keeps running after KUAL
# and the reading interface close.
D="$(cd "$(dirname "$0")" && pwd)/dash.sh"
if command -v setsid > /dev/null 2>&1; then
	setsid /bin/sh "$D" < /dev/null > /dev/null 2>&1 &
elif command -v start-stop-daemon > /dev/null 2>&1; then
	start-stop-daemon -S -b -x /bin/sh -- "$D"
else
	nohup /bin/sh "$D" < /dev/null > /dev/null 2>&1 &
fi
