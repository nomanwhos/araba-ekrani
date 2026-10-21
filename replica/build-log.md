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
| S14 Player | 2026-10-20 | partial | stream switch, subtitles/audio menus, fit/fill, A/V offset; not yet seen playing | needed a shared AVPlayer owner so the mini player and the full player stay in sync |
| S15 Mini player | 2026-10-20 | partial | not yet seen on a device | — |

Data layer: real, not fake. GRDB/SQLite with the schema from `replica/schema.sql`, an importer that upserts by stable key, and 5 new test files with 24 cases (30 with the mirroring tests), including a 20,000-entry import. There is no backend to swap in; replica-backend applies only to the media-server sources (Xtream, Jellyfin, Emby, Plex).
