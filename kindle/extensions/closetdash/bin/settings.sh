# Closet Dash settings. Times are 24-hour HHMM, Kindle local time.

BASE="https://pmoto77-bit.github.io/closet-kindle"

FETCH_TIMES="0530 1200 1800"   # scheduled downloads
CHECK_MIN="30"                 # between scheduled times, look this often for a newer build
TOMORROW_FROM="1800"          # from this time on, show tomorrow's picture

LIGHT_ON="0600"                # front light window
LIGHT_OFF="0900"
LIGHT_LEVEL="8"                # 0-24

RETRY_MIN="10"                 # after a failed download, retry this often...
RETRY_FAST_TRIES="9"           # ...this many times (about 90 minutes),
RETRY_SLOW_MIN="30"            # then this often, and show a warning on screen

LOW_BATTERY="20"               # show a battery warning below this %

WIFI_OFF_BETWEEN="0"           # 1 = turn Wi-Fi off between downloads (saves battery;
                               #     try only after the display has run reliably)
