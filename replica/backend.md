# Backend: Torpido

Torpido has no server of its own (architecture.md): one owner, one iPhone, no accounts. Most of this skill does not apply, and each part says why. What does apply is the integrations with the owner's own media sources, and the security of their credentials.

| part | status | why |
| --- | --- | --- |
| auth / sign up / sessions / roles | not applicable | no accounts (PRODUCT.md). The only "accounts" are the owner's IPTV and Jellyfin logins, kept in the Keychain |
| account deletion | partial | removing a source deletes its channels, favourites, positions and Keychain item. A "delete everything" row is still to build (architecture.md) |
| database | done | GRDB/SQLite on the device, migration v1 = `replica/schema.sql`, checked in and run at launch. No second user exists, so there is no row-level security; isolation is the app sandbox |
| seed data | done | DEBUG `-TorpidoSeed 1`: synthetic channel names on Apple's public HLS test streams, no real people |
| backups | n/a | the database is rebuilt from the owner's sources; iCloud device backup covers it |
| payments / Stripe / webhooks | not applicable | personal app, no payments |
| email | not applicable | — |
| jobs | partial | source refresh is manual (Kaynaklar › swipe › Yenile). `BGAppRefreshTask` and the health check are listed in architecture.md |
| `.env.example` | not applicable | no server keys exist. Every secret is something the owner types into the app, and it goes to the Keychain |

## Integrations

| integration | API | what Torpido calls | credentials | limits and review | status |
| --- | --- | --- | --- | --- | --- |
| M3U playlist | plain HTTP GET of the owner's playlist URL | the URL, streamed line by line | URL with query/user-info → Keychain; the database keeps a credential-free form | none; a 50 MB+ list is streamed | done |
| Xtream Codes | the owner's provider's `player_api.php` | login (`user_info`), `get_live_categories`, `get_live_streams`; play URL `/live/<user>/<pass>/<id>.<m3u8\|ts>` built at play time | server and username in the database; password in the Keychain; stream rows stored as `xtream:live/<id>.<ext>` | providers cap concurrent streams (often 1-2) and may ban heavy clients: no prefetching, no automatic health checks for Xtream | done (live TV). VOD and series: not yet |
| Jellyfin | official REST API (jellyfin.org/docs, `/api-docs`) | `POST /Users/AuthenticateByName`, `GET /Users/{id}/Views`, `GET /Users/{id}/Items?ParentId=`, `GET /Videos/{id}/master.m3u8` (H.264/AAC HLS, server transcodes), `POST /Sessions/Playing`, `/Progress`, `/Stopped` | server and username in the database; access token and user id in the Keychain; the password is never stored | none from Jellyfin; a server outside the home network needs the owner's own remote access | done: sign-in, browse libraries, series, seasons and episodes, play with server-side resume |
| Emby | official API, nearly the same as Jellyfin | not built | — | — | could |
| Plex | official API (plex.tv PIN sign-in) | not built | — | — | could |
| DLNA receiver | UPnP AV spec | not built | — | needs Apple's multicast entitlement, a separate request from CarPlay | could |
| CarPlay | Apple entitlement | — | — | Apple review; the request is the owner's to send | waiting on Apple |

There are no OAuth scopes to request. All Jellyfin and Xtream calls use the owner's own username and password, on servers they control or pay for. No CarTV endpoint (`api.cartv.app`) is called.

## Security checklist

- [x] **Secrets.** In the Keychain (`AfterFirstUnlockThisDeviceOnly`), never in SQLite, UserDefaults, logs or URLs that get stored. Tests check that no password or token reaches the database (StoresTests, XtreamTests, JellyfinTests).
- [x] **Input validation.**
  - Playlist URLs must be http(s) with a host.
  - Server addresses are normalised and validated (`HTTPClient.serverURL`).
  - Server responses are decoded leniently, and bad JSON becomes `unexpectedResponse`, never a crash.
  - Playlist frames and sizes are bounded.
- [x] **Authorisation.** Single user; nothing to check. Every Jellyfin request carries the owner's own token.
- [ ] **Rate limits.** The app makes no automatic calls yet. When the health check lands it is capped at 4 concurrent requests, with a 30-minute minimum interval and off for Xtream (architecture.md).
- [x] **Webhooks.** None.
- [x] **Uploads.** None. Local video import is a could-have and will check free space.
- [x] **No user data in URLs or logs.**
  - The app has no logging.
  - Error messages never include URLs.
  - URLs with credentials (Xtream play URLs, Jellyfin `api_key`) are built in memory at play time only.
- [x] **Dependencies.** GRDB.swift 7 (MIT), pinned by SPM `from: 7.0.0`. Nothing else.
- [x] **Privacy.** No processors: no analytics, no ads, no crash reporter. Network traffic goes only to the sources the owner adds and to the playlist and logo URLs inside them.
- [ ] **Transport.** `NSAllowsArbitraryLoads` is on, because most IPTV runs over plain http. This is acceptable for a personal build and would block an App Store submission.
