# Parity: Torpido vs CarTV (2026-10-22)

**Overall 40.3 / 100**
- **Features:** 45.1. 38 features counted; must-haves 9 of 9 done.
- **Layout:** 21.3, over 3 screens.

Source of the numbers: `parity.py replica/features.csv --visual replica/diffs/*.json` (replica-diff), with skip rows left out.

**Verdict: shippable for its one user, not "better than the original" yet.**

What qualifies it:
- All must-haves are done.
- There are no open S1 or S2 bugs (bugs.md).

What holds it back:
- The feature score is 45, under the 80 bar.
- replica-entrepreneur has not run.
- Mirroring cannot run in the car until Apple grants the CarPlay entitlement. That is the product's main job, and it is outside the code.

## Features by area (weakest first)

| area | score | what is missing |
| --- | --- | --- |
| local videos | 0 | import from Files/Photos, offline play, rename/reorder |
| search | 0 | channel search, history, voice |
| car | 0 | car mode layout, channels on the CarPlay screen, rotary knob |
| browser | 0 | in-app browser |
| help | 0 | FAQ (Torpido has "Nasıl çalışır" only) |
| player | 45 | subtitles, audio tracks, fit/stretch, stream switch, speed, visualizer, MKV fallback |
| casting | 60 | DLNA receiver, Live Activity (mirroring itself is built) |
| favorites | 60 | drag to reorder |
| sources | 62 | QR add, rename, Xtream VOD/series, Emby, Plex |
| library | 58 | health check (the badge exists, but no data feeds it yet) |

## Layout (structure only, colour ignored)

| screen | score | note |
| --- | --- | --- |
| S01 Home, empty | 25.1 | different |
| S02 Favorites, empty | 16.0 | different |
| S08 Settings | 22.8 | different |

The low layout scores are expected and mostly intended. CarTV is light-mode grouped lists with green accents. Torpido is the dark "drive-in" world from DESIGN.md, with a different marquee/perde composition and Turkish copy.

The comparison is also rough:
- The originals are 384 px frames from a compressed screen recording.
- The two Favorites screens are not in the same state: CarTV's shows its Local sub-tab empty, and Torpido's shows two seeded favourites.

Matching CarTV's look is not a goal (trade dress). The information is in the same places: four tabs, an empty state with one action, and grouped settings.

## Behaviour differences

| flow | CarTV does | Torpido does | fix or keep |
| --- | --- | --- | --- |
| F02 mirror | Discover › Cast to Screen › paywall for free users › system sheet: 4 taps plus the paywall | Perde › Yansıtmayı Başlat › Yayını Başlat: 3 taps, no paywall | keep (better) |
| F01 add playlist | + › source type › paste › save; errors "Download failed" / "Not a valid channel playlist" | same steps; Turkish errors that say why (expired link, no #EXTM3U) and what to do | keep |
| F01 credentials | stores playlist and server credentials on the device (privacy policy) | Keychain only; the database never sees passwords or tokens (tested) | keep |
| F04 Jellyfin resume | resumes where you stopped | resumes from the server and reports progress back, so other Jellyfin apps agree | keep |
| launch | announcements and settings from api.cartv.app; Adjust/Meta tracking prompt | no network calls except the owner's sources; no tracking | keep |
| F01 dead channels | background check hides them on Home | hidden when marked down, but nothing marks them yet | build the health check |
| player | subtitles, audio tracks, speed, size controls | system player only, plus favourite and shrink | build (top 5) |

## Next five to build
1. **Channel search** (S18). Biggest everyday gap with a large playlist. The FTS5 table already exists; fix the rowid note in bugs/build-log first.
2. **Player controls:** subtitles and audio track menus (AVMediaSelection), fit/fill, stream switch on failure. Raises the weakest high-use area.
3. **Health check job**, rate-limited and off for Xtream. Hides dead channels and finally feeds the latency badge.
4. **Manual A/V delay offset.** The reviews asked for it and CarTV lacks it; it is the first "better than the original" item.
5. **Local videos:** import from Files/Photos and play offline. Parked or camping without signal is the scene PRODUCT.md describes.

After these: `/replica-entrepreneur` for the rest of the "better than" list.
