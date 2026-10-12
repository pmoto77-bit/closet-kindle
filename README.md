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
- **Battery:** the 2012 battery charges for about 3 hours each night on an outlet timer (2–5 AM). Every few months, check the back of the Kindle for bulging. If it's swollen, unplug it and retire the Kindle.

## Status
- [x] Phase 1: image generator, rules, layout, self-tests (on the PC)
- [ ] Phase 2: GitHub repo and Pages (`pmoto77-bit/closet-kindle`)
- [x] Phase 0: jailbreak the Kindle (done on a separate computer; downgrade to 5.3.3 → K5 JailBreak → DevCerts → MRPI + KUAL → back to 5.6.1.1)
- [ ] Phase 3: Kindle program, starting with the HTTPS download test

Fonts: Selawik (SIL Open Font License; see `generator/fonts/LICENSE-Selawik.txt`).
