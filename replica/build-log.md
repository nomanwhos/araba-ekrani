# Build log

One line per screen: ID, date, status, what is missing, what was harder than expected.
Screenshots for replica-diff are in `replica/clone-screens/`, captured on CI (iPhone simulator, iOS 26.5 SDK, dark).

| ID | date | status | missing | harder than expected |
| --- | --- | --- | --- | --- |
| shell | 2026-10-20 | done | — | Tabs went from 2 to 4 (Ana Sayfa, Favoriler, Perde, Ayarlar). CarTV's Discover maps onto the existing Perde tab |
| S01 Home | 2026-10-20 | done | search (S18), car-mode layout | one window-function query instead of N+1 per group; the 20-per-group cap keeps 100k-channel lists fast |
| S01b Group | 2026-10-20 | done | sort/filter | — |
| S02 Favorites | 2026-10-20 | partial | drag to reorder; the local videos segment waits for S19 | — |
| S05 Perde (mirroring) | 2026-10-16 | done | runs in the car only with Apple's CarPlay entitlement | ReplayKit extension memory ceiling, loopback transport |
| S08 Settings | 2026-10-20 | done | delete-all-data row | — |
| S09 Sources | 2026-10-20 | partial | rename, reorder | — |
| S09b Add source | 2026-10-20 | partial | QR scan, Xtream, Jellyfin/Emby/Plex | one Swift rule (exclusive access) broke the first CI build: `pending?.group = pending?.group ?? x` |
| S14 Player | 2026-10-21 | partial | stream switch, subtitles/audio menus, fit/fill, A/V offset (playback itself verified on CI) | needed a shared AVPlayer owner so the mini player and the full player stay in sync |
| S15 Mini player | 2026-10-20 | partial | not yet seen on a device | — |

Data layer: real, not fake. GRDB/SQLite with the schema from `replica/schema.sql`, an importer that upserts by stable key, and 5 new test files with 24 cases (30 with the mirroring tests), including a 20,000-entry import. There is no backend to swap in; replica-backend applies only to the media-server sources (Xtream, Jellyfin, Emby, Plex).

## Review fixes (2026-10-21)

Code review of the slice found no compile errors and these bugs, all fixed:
- **Credentials:** IPTV playlist URLs with credentials (query or user-info) are now kept in the Keychain. `sources.url` holds only a credential-free form. Tested.
- **Diğer row:** down channels without a group no longer show there.
- **Failure feedback:** a channel with no stream URL now opens the player with an error instead of doing nothing.
- **Failed import:** a failed first import removes the half-created source.
- **File protection:** the database file protection is now set through `URLResourceValues`. The old call silently did nothing.
- **Mini player:** it now also shows on Perde, Ayarlar and Kaynaklar.

Resolved by migration v2: the FTS table is gone; search uses the folded `search_name` column.

2026-10-21: S14 was verified on CI. `-TorpidoPlay 1` starts the first seeded channel, and the screenshot shows Apple's HLS test stream playing at 00:00:15 with the favourite star lit. Two more compile fixes came after the review: an `await` on GRDB's async `read` inside `.task`, and `URLResourceValues.fileProtection` turned out to be read-only, so it is set through `FileManager` instead.

| S18 Search | 2026-10-22 | done | voice search | FTS5 dropped in migration v2: unicode61 cannot fold dotless ı, and the TEXT-keyed rowid risk goes away with it. A folded `search_name` column with LIKE (top 200) is simpler and fast enough |
| S14 Player controls | 2026-10-22 | partial | stream switch, A/V offset | Fit/fill button added. Subtitles, audio tracks and speed come from the system player menu, not rebuilt. Two things are bigger than they looked: switching playback sources needs the importer to group same-channel URLs first, and AVPlayer has no audio offset for HLS, so A/V delay needs its own audio pipeline |
| Health check job | 2026-10-23 | done | BGAppRefreshTask (runs on foreground only) | kept deliberately small and polite: M3U only, 80/run, 4 parallel, 3 s, 30 min per channel |

2026-10-23: first run on the owner's iPhone (TestFlight build 41). The iptv-org Turkey M3U list imported, channels listed on Home and played. This is the first on-device confirmation of F01.
| S19 Local videos | 2026-10-23 | partial | drag reorder | Files and Photos import with a 500 MB free-space reserve; offline play with resume; rename/delete remove the file, the position and the favourite |
| S07 Browser | 2026-10-23 | done | — | Netflix and Prime refuse browser playback on iPhone, and their DRM video comes out black when mirrored. Said plainly on the start page and in Ayarlar instead of promising it |
