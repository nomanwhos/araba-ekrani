# Architecture: Torpido (a rebuild of CarTV's core features)

Inputs: `replica/recon.md`, `replica/features.csv` (2026-10-20). Constraints from PRODUCT.md: one owner, one iPhone, no account, no payments, no tracking, no network calls the owner did not ask for, native iOS (Torpido v0.1 is already SwiftUI + CarPlay + ReplayKit).

The clone needs CarTV's features, not its architecture. Everything runs on the phone; there is no Torpido server.

## Stack

| layer | choice | why |
| --- | --- | --- |
| app | SwiftUI, iOS 18+, Swift 5 mode (existing Torpido) | already built and on CI; CarPlay and ReplayKit are native-only |
| database | SQLite through GRDB.swift (SPM) | 100k-row playlist imports in one transaction, FTS5 search, real migrations, value observation for SwiftUI. SwiftData is slow at bulk insert and has no full-text search |
| secrets | Keychain (`kSecClassGenericPassword`, `AfterFirstUnlockThisDeviceOnly`) | Xtream passwords and media-server tokens never touch SQLite or UserDefaults |
| preferences | UserDefaults | fill mode (exists), A/V offset, visualizer style, health-check toggle |
| networking | URLSession (`bytes(from:)` for streaming playlist parse) | no dependency; playlists are parsed line by line as they download |
| player | AVPlayer / AVPlayerViewController first; VLCKit later as fallback | AVPlayer covers HLS, HTTP, MP4/MOV, subtitles and audio tracks via AVMediaSelection. MKV/HEVC-in-MKV/DTS need VLCKit (LGPL, fine for personal use) - a could-have |
| media servers | official public REST APIs: Jellyfin, Emby, Plex | owner's own server and credentials only |
| casting receiver | Network.framework: UDP multicast (SSDP) + small HTTP server (UPnP device XML, AVTransport SOAP) | DLNA/UPnP is a public spec; no third-party SDK |
| background jobs | in-app on launch/foreground + `BGAppRefreshTask` | iOS gives no guaranteed schedule; jobs must also run when the app opens |
| CarPlay | existing `CPTemplateApplicationScene` (carplay-maps entitlement) | navigation apps may push `CPListTemplate`/`CPSearchTemplate` for browsing and draw video in the `CPWindow` |
| auth | none | no accounts (PRODUCT.md) |
| payments | none | personal app |
| email | none | — |
| hosting / distribution | none; GitHub Actions macOS CI (exists), device install once the Apple account and entitlement exist | no Mac available |

New dependencies: GRDB.swift (MIT). Later, optionally: VLCKit. Nothing else.

## Schema

Tables: 10 (+1 FTS5 virtual table). Full SQL: `replica/schema.sql`, migration v1, checked in SQLite 3 on 2026-10-20 (cascade deletes, FTS triggers, diacritic folding).

Access rules: data-layer only. Single user on one device, so there are no owner columns and no row-level security. Protection comes from the app sandbox, Data Protection on the database file (`completeUntilFirstUserAuthentication`, so background refresh can still open it), and the Keychain for secrets.

Rule deviations from the replica default, on purpose:
- IDs are TEXT UUIDs, and times are INTEGER Unix seconds UTC (SQLite has no uuid or timestamptz type).
- No `user_id` anywhere: one owner.
- No money columns: no payments.

| table | holds | key decisions |
| --- | --- | --- |
| sources | M3U / Xtream / Jellyfin / Emby / Plex | `kind` and `status` are CHECKed; secret only referenced by `keychain_account` |
| channel_groups | `group-title` rows | `UNIQUE(source_id, title)`, cascade with source |
| channels | playlist entries | `stable_key` (`UNIQUE(source_id, stable_key)`) survives refresh; group delete → SET NULL |
| channel_streams | 1..n URLs per channel | lets the player switch playback source |
| channels_fts | FTS5 over names | `unicode61 remove_diacritics 2`; Turkish İ/ı folded in Swift |
| media_items | cached server library tree | `UNIQUE(source_id, remote_id)`, sorted by `index_number` |
| local_videos | imported files | `file_name` UNIQUE inside the container |
| favorites | polymorphic pointer + `sort_order` | no FK (channel/media/local); cleanup job drops orphans |
| playback_positions | resume + recently played | PK `(item_kind, item_key)`; `duration_s` NULL for live |
| search_queries | history | `text` UNIQUE, re-search bumps the time |
| bookmarks | browser favourites | `url` UNIQUE |

Hard constraints the recon found, enforced in the database:
- A playlist refresh must not orphan favourites → `stable_key` plus favourites keyed by `source_id:stable_key`, not by row id.
- Duplicate entries in one playlist (same name and group) → `stable_key` gets a `#n` suffix in parse order, so the UNIQUE index never rejects a real playlist.
- Search must ignore Turkish accents → folded index, folded query.

## API

There are no Torpido HTTP routes. The "API" is the app's service layer (Swift `actor`s), plus the official external APIs it calls with the owner's own credentials. Never CarTV's endpoints (`api.cartv.app` is out of scope).

### Service operations

| operation | does | caller | input | output | flow |
| --- | --- | --- | --- | --- | --- |
| `SourceService.addM3U(url:name:)` | validate `#EXTM3U`, download, parse, insert in one transaction | S09b | URL, optional name | `Source` or `.invalidPlaylist` / `.downloadFailed` | F01 |
| `SourceService.addXtream(server:user:password:)` | `player_api.php` auth, store secret in Keychain, import live categories + streams | S09b | server URL, user, password | `Source` or `.authFailed` | F01 |
| `SourceService.addMediaServer(kind:url:user:password:)` | Jellyfin/Emby `AuthenticateByName` → token in Keychain; Plex PIN sign-in | S09b | kind, URL, credentials | `Source` | F04 |
| `SourceService.refresh(id:)` | re-download and diff by `stable_key` (upsert + delete missing) | S09, launch job | source id | counts added/removed | F01 |
| `SourceService.rename(id:name:)` / `remove(id:)` / `reorder(ids:)` | manage list; remove deletes the Keychain item too | S09 | id(s) | — | F01 |
| `QRScanner.scan()` | camera → URL string → `addM3U` | S09b | — | URL | F01 |
| `LibraryStore.groups(source:)` / `channels(group:)` | observed queries for Home rows and group lists, hiding `health = 'down'` on Home only | S01, S01b | ids | live arrays | F01 |
| `LibraryStore.search(text:)` | FTS5 match on folded text, top 200, then records history | S18 | text | channels | F07 |
| `SearchHistory.recent()` / `clear()` | history list | S18 | — | queries | F07 |
| `MediaServerService.children(of:)` | live fetch + cache into `media_items` | S16 | source, parent | items | F04 |
| `MediaServerService.streamURL(item:)` | Jellyfin/Emby `PlaybackInfo` → direct play or transcode URL; Plex part URL | S14 | item | URL + headers | F04 |
| `MediaServerService.reportProgress(item:position:)` | sends resume position back to the server | S14 (every 10 s, on pause/stop) | item, seconds | — | F04 |
| `LocalVideoService.import(from:)` | copy from Files/Photos into the container, check free space first | S02, S06 | `URL` or `PHPickerResult` | `LocalVideo` | F05 |
| `LocalVideoService.rename` / `delete` / `reorder` | manage files and rows together | S19 | id(s) | — | F05 |
| `Favorites.toggle(item:)` / `reorder(ids:)` / `list()` | favourites | S01, S02, S14 | item ref | — | F06 |
| `PlayerController.play(item:)` | resolve URL(s), restore position, start AVPlayer, apply A/V offset | S14, S15, CarPlay | item | session | F01, F04, F05 |
| `PlayerController.switchStream()` | next `channel_streams` URL on failure or by hand | S14 | — | — | F01 |
| `PlayerController.select(subtitle:)` / `select(audio:)` | AVMediaSelection groups | S14 | option | — | F01 |
| `PlayerController.savePosition()` | upsert `playback_positions` every 10 s and on pause | S14 | — | — | F01, F04, F05 |
| `MirrorServer` (exists) | ReplayKit frames → CarPlay window | Perde tab | — | — | F02 |
| `DLNARenderer.start()` / `stop()` | SSDP announce + HTTP device description + AVTransport `SetAVTransportURI`/`Play`/`Pause`/`Seek`/`Stop` | S06 | — | incoming URL → `PlayerController` | F03 |
| `CarPlayBrowser` | `CPListTemplate` of favourites, recent, groups; `CPSearchTemplate`; tap → play in `CPWindow` | CarPlay | — | — | F08 |

### External APIs (official and public, owner's credentials)

| API | calls used |
| --- | --- |
| M3U / HTTP | `GET <playlist url>` (streamed) |
| Xtream Codes (provider's `player_api.php`) | `?username&password` (auth), `&action=get_live_categories`, `&action=get_live_streams`; stream URL `/<user>/<pass>/<id>.ts\|m3u8` |
| Jellyfin / Emby | `POST /Users/AuthenticateByName`, `GET /Users/{id}/Views`, `GET /Users/{id}/Items?ParentId=`, `POST /Items/{id}/PlaybackInfo`, `POST /Sessions/Playing`, `/Sessions/Playing/Progress`, `/Sessions/Playing/Stopped` |
| Plex | `POST https://plex.tv/api/v2/pins` + poll (PIN sign-in), `GET /library/sections`, `/library/metadata/{id}/children`, `:/timeline` for progress |
| UPnP AV (receiver side) | SSDP `NOTIFY`/`M-SEARCH` on 239.255.255.250:1900, `GET /description.xml`, SOAP to `/AVTransport/control` and `/RenderingControl/control` |

Webhooks in: none. Webhooks out: none.

Jobs:

| job | schedule | does |
| --- | --- | --- |
| `refreshStaleSources` | on launch/foreground + `BGAppRefreshTask` (earliest every 6 h) | refresh sources older than 24 h |
| `channelHealthCheck` | after a refresh and on foreground, at most every 30 min; off by default for Xtream | short GET of first stream URL, 4 at a time, 3 s timeout, only channels in Home rows; sets `health` and `latency_ms` |
| `cleanupOrphans` | after every refresh/remove | delete `favorites` and `playback_positions` whose target is gone; delete local files with no row |
| `pruneHistory` | on launch | keep the newest 50 search queries and 200 playback positions |

## The parts that bite

- **Time zones:** nothing is scheduled by wall-clock time (no EPG yet). Store UTC seconds; format with the device zone.
- **Idempotency:** refresh is an upsert by `(source_id, stable_key)`, so running it twice changes nothing. DLNA control points resend `SetAVTransportURI`; treat an identical URI as a no-op.
- **Races:** a refresh and the health check can write the same rows. Use one GRDB `DatabasePool` writer (serialised writes) and let the health check skip channels whose source is refreshing. Two broadcasts at once is already handled (MirrorServer keeps one connection).
- **Rate limits:** IPTV providers often allow 1-2 concurrent streams and ban accounts that open many connections. The health check is capped at 4 parallel, runs only on Home-row channels, and is opt-in for Xtream. Never prefetch streams.
- **Secrets in URLs:** Xtream stream URLs embed username and password in the path. Never log stream URLs, and redact them in error messages.
- **ATS:** most IPTV streams are plain `http://`. Info.plist needs `NSAllowsArbitraryLoadsForMedia` (AVPlayer). Playlist downloads may need `NSAllowsArbitraryLoads`, which is acceptable for a personal, non-store build.
- **File size:** playlists can be 50 MB+. Stream-parse, insert in batches of 5,000 inside one transaction, and show progress. Local imports check free space first and copy, not move.
- **Search:** FTS5 with diacritics removed. Turkish `İ`/`ı` do not lowercase correctly under the default locale, so fold with `tr_TR` rules in Swift on both the indexed text and the query.
- **Offline:** cached groups, channels, server trees and local videos browse offline; only playback needs the network (local videos excepted).
- **Local network and multicast:** DLNA needs the Local Network permission and Apple's `com.apple.developer.networking.multicast` entitlement, which has its own request form. That is a second Apple approval, separate from CarPlay.
- **CarPlay:** video in the car window needs the carplay-maps entitlement (pending). Driver distraction: play video only for a passenger or when parked; the app already says so, and CarPlay list browsing stays template-based.
- **Background:** iOS suspends the app; the mirror listener restarts on foreground (exists). Playback in the background needs the `audio` background mode, and for video only PiP, which is not in scope.
- **Deletion:** a "Delete all data" row in Settings drops the database, imported videos, Keychain items and web data in one go.

## Build order

1. **Vertical slice: an M3U channel plays.** Add Source (URL only) → parse → store → Home lists groups and channels as plain rows → tap → AVPlayer full screen.
   - Screens: S09b (minimal), S01, S14 (system player).
   - Tables: sources, channel_groups, channels, channel_streams.
   - Ops: `addM3U`, `LibraryStore.groups/channels`, `PlayerController.play`.
   - Done when a real playlist with 10k+ entries imports in under 10 s on CI's simulator test, and a stream plays.
   - Tabs change from Perde · Ayarlar to Ana Sayfa · Favoriler · Perde · Ayarlar (CarTV's Discover becomes Perde, which already exists).
2. **Must-haves** (features.csv `must`):
   - S01 with logos, group rows and empty states
   - resume (`playback_positions`)
   - favourites (`favorites`) on S01, S02 and S14
   - S02 empty states
3. **Should-haves**, by area:
   - **Sources:** S09 refresh/rename/remove, QR add, Xtream, Jellyfin (S16).
   - **Local videos:** S02/S19 import, rename, delete, reorder.
   - **Search:** S18 with FTS5.
   - **Player:** subtitles, audio tracks, mini player S15, stream switch, fit/stretch.
   - **Car:** car mode S17, CarPlay list → play in window.
   - **Library jobs:** health check, reorder favourites.
4. **Could-haves:**
   - DLNA receiver (S06, needs the multicast entitlement)
   - VLCKit fallback, Emby, Plex
   - voice search, search history
   - browser S07
   - speed control, visualizer, latency badge, rotary knob, Live Activity, FAQ
5. **Fixes from replica-entrepreneur:** not run yet. The recon already flagged these, ahead of the could-haves:
   - manual A/V delay offset (which CarTV lacks)
   - CarPlay search
   - "Recently played" from `playback_positions`
   - size controls that auto-hide
   - pause on incoming calls
