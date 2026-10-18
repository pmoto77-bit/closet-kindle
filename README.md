# Closet Kindle

A Kindle Paperwhite 1 in the closet that shows the day's weather for Grand Rapids and **what to wear**. It updates on its own three times a day, and after 6 PM it switches to tomorrow's forecast.

```
GitHub (3x/day)                               Kindle (jailbroken, KUAL)
 fetch Open-Meteo + NWS alerts                 5:30 AM / 12 PM / 6 PM
 apply clothing_rules.json         ──Pages──▶  download today.png or tomorrow.png
 draw today.png + tomorrow.png                 show it; warn on screen if it's stale
```

## Folder map
| Path | What it is |
|---|---|
| `generator/clothing_rules.json` | **The clothing rules.** This is the file to edit. |
| `generator/config.json` | Location (city-level), the comfort setting, screen size and time windows |
| `generator/*.py` | Code: `fetch` (data), `rules` (what to wear), `render` (the picture), `samples` (made-up test days) |
| `tests/` | Self-tests. Run them with `python -m unittest discover -s tests` |
| `preview.bat` | Double-click to render every sample day plus today's real forecast into `preview\` |
| `.github/workflows/build.yml` | The cloud job that builds and publishes the images |
| `kindle/` | The Kindle program (KUAL extension). Added in Phase 3, after the jailbreak |
| `docs/mockups/` | The approved Layout C reference images |
| `data/` | Build log written by the cloud job (`status.json`, `history.csv`) |

## Changing what it suggests
1. Open `generator/clothing_rules.json`. You can edit it on github.com with the pencil icon.
2. Change any of these:
   - The words in quotes.
   - The `below` numbers in `warmth_bands`.
   - The numbers in `triggers`, which control when a reason line appears.
   - Keep `{curly}` words as they are.
3. Save or commit. The cloud job re-renders within a few minutes, and the Kindle picks up the change at its next check.
4. On a PC, run `preview.bat` first to see the effect on every sample day.

**"I run cold":** set `comfort_offset_f` in `config.json` to `5`. Warmer clothes are then suggested 5° sooner. Use `-5` if you run warm.

**When reason lines appear:** only when something you can't see from the temperatures changed the choice:
- feels-like at least 5° colder than the actual temperature
- gusts of 30 mph or more (or sustained wind of 20+)
- a rise of 15° or more from morning to afternoon
- UV 6 or higher
- rain timing
- heat index 90° or higher
- ice
- unhealthy air

If the screen gets crowded, reasons are dropped in the order listed in `reason_priority`.

## Where the data comes from
- **Forecast and air quality:** [Open-Meteo](https://open-meteo.com), free with no API key. It uses NOAA models for the US.
- **Alerts:** National Weather Service `api.weather.gov`. NWS requires a contact address in each request, so the requests use the GitHub noreply address.
- The alert banner and air quality line appear only when relevant. If either source is down, the screen says "…unavailable this update," so a missing alert never looks like "no alerts."

## Health checks
- **GitHub:** the Actions tab shows every run. A failed run (for example, the forecast couldn't be downloaded) sends an email, and the last good images stay up.
- **Kindle:** if it can't get a fresh image, it stamps "Not updated since…" on the screen instead of showing old weather as current.
- **Battery:** the plan is for the 2012 battery to charge for about 3 hours each night on an outlet timer (2–5 AM). The timer isn't installed yet. In October 2026 the battery used about 1.7% per hour, so a 3-hour nightly charge is plenty. Every few months, check the back of the Kindle for bulging. If it's swollen, unplug it and retire the Kindle.

## Putting the Kindle program on the Kindle
1. On github.com, go to the repo and click **Code → Download ZIP**. Unzip it.
2. Plug in the Kindle. Copy the folder `kindle/extensions/closetdash` into the Kindle's `extensions` folder, next to `MRInstaller`.
3. Eject the Kindle. Then open **KUAL → Closet Dash**.

**Test download** checks whether this Kindle can fetch the images over HTTPS. It changes nothing on the Kindle. It shows the result on screen and writes details to `extensions/closetdash/test-result.txt`.

**Start** runs the display:
- It pauses the Kindle's reading interface, so nothing draws over the picture.
- It downloads at 5:30 AM, 12 PM and 6 PM, and from 6 PM shows tomorrow's picture.
- Between those times it checks every 30 minutes for a newer build (the cloud job runs hourly).
- It turns the front light on from 5:30 to 8 AM.
- If a download fails, it retries every 10 minutes. After about 90 minutes it writes a warning at the top of the screen.
- Downloads are verified with the bundled `cacert.pem` (Mozilla's CA list, from curl.se). If that fails, it falls back to an unverified download.
- Times and settings are in `bin/settings.sh`. The log is in `dash-log.txt`.

**Touch setup (once).** The first time you press Start, three screens each show a black dot. Tap each dot. This teaches the program where the menu buttons are, because the touchscreen's raw numbers don't match screen pixels. The result is saved in `touch.conf`. **KUAL → Closet Dash → Redo touch setup** clears it.

**The tap menu (kid-proof exit).** Tap the screen anywhere to open the menu:
- **REFRESH NOW** gets the latest forecast.
- **BACK TO WEATHER** closes the menu.
- **EXIT TO KINDLE** is the small button in the bottom-right corner. It asks **"Exit to the Kindle?"**: tap the small **YES, EXIT** in the top-left corner to leave, or the big **NO** to stay.

The menu closes by itself after 15 seconds, and the question after 10. Leaving takes two specific taps in opposite corners, so random taps keep the weather on screen. Settings: `MENU_TIMEOUT` and `CONFIRM_TIMEOUT` in `bin/settings.sh`.

**Auto-start after a restart (optional).**
- **KUAL → Closet Dash → Enable auto-start after restart** installs a small startup file (`/etc/upstart/closetdash.conf`) and writes `autostart-log.txt`.
- After the Kindle restarts, it waits 30 seconds. It then shows **"Closet Dash starts in about a minute — tap anywhere to cancel."**
  - A tap returns the normal Kindle for that boot.
  - With no tap, the weather display starts.
- **Disable auto-start** removes it.
- **Kill switch:** a file named `STOP_CLOSETDASH` at the top level of the Kindle drive also stops auto-start.

**If the Kindle ever seems stuck:** hold the power button for about 40 seconds to restart it.
- If auto-start is off, it comes back as a normal Kindle.
- If auto-start is on, tap during the countdown.

## Status
- [x] Phase 1: image generator, rules, layout, self-tests (on the PC)
- [x] Phase 2: GitHub repo and Pages (`pmoto77-bit/closet-kindle`); builds run hourly
- [x] Phase 0: jailbreak the Kindle (done on a separate computer; downgrade to 5.3.3 → K5 JailBreak → DevCerts → MRPI + KUAL → back to 5.6.1.1)
- [x] Phase 3: Kindle program v0.2. It ran from Oct 11 to Oct 15, 2026 with every download succeeding.
- [ ] v0.3: tap menu with confirm, touch setup, optional auto-start. Being tested on the Kindle.

Kindle screens (menu, confirm, touch setup, boot) are drawn by `generator/make_kindle_screens.py`. It also writes `img/buttons.txt` with the tap areas.

Fonts: Selawik (SIL Open Font License; see `generator/fonts/LICENSE-Selawik.txt`).
