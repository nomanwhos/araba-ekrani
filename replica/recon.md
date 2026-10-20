# Recon map: CarTV – M3U IPTV Player & Cast (iOS)

Scope: the whole app. Screen mirroring to the car display (already rebuilt as Torpido v0.1), the M3U/IPTV player, media-server sources, local videos, casting receiver, in-app browser, car mode.
For: the owner only. Personal use, no App Store, no payments (see PRODUCT.md).
Date: 2026-10-20

Clean-room note: everything below comes from public pages and the owner's own screen recording of the app on their own phone (free tier, not signed in to Pro). No binary, bundle, network traffic or private API was inspected. Reference screenshots in `replica/screens/` are for layout comparison only and never ship.

## Sources

| # | source | URL | notes |
| --- | --- | --- | --- |
| 1 | marketing site + FAQ | https://cartv.app/ | feature list, 10 FAQ entries, Pro benefits, cast-receiver app list |
| 2 | App Store listing | https://apps.apple.com/us/app/cartv-m3u-iptv-player-cast/id6800211040 | description, IAP prices, version history 1.0.0 (Aug 16) → 1.1.5, privacy labels, 22 languages, iOS 18+ |
| 3 | App Store reviews | https://apps.apple.com/us/app/6800211040?see-all=reviews&platform=iphone | 4.5★ / 4.3K ratings; ~10 reviews visible; complaints and requests |
| 4 | terms (linked from listing) | https://27ef9698.pinme.dev/terms.html | titled "Lyntra Player", not CarTV; says no IAP, which contradicts the app. Bans reverse engineering; no anti-competition clause |
| 5 | privacy (linked from listing) | https://27ef9698.pinme.dev/privacy.html | also "Lyntra Player"; the in-app policy (S11) differs and names Umeng, FirstFew, Adjust, Meta |
| 6 | in-app Terms (EULA) | Apple Standard EULA on apple.com (S12) | standard licence; no-reverse-engineering clause; no competing-product clause |
| 7 | owner's screen recording | `C:\Users\aliha\Downloads\WhatsApp Video 2026-10-16 at 12.05.37 PM.mp4` (55 s, CarTV 1.1.3 build 48) | frames in `replica/screens/raw/`, one canonical frame per screen in `replica/screens/` |

Terms check: the licence forbids reverse engineering and redistributing *the app*. Rebuilding its features for personal use from public information and ordinary use does neither, and no clause forbids building a competing product. Nothing of CarTV's (name, art, copy, code) goes into Torpido.

## Core loop

Paste an IPTV playlist (or sign in to your own media server) once, then pick a channel or episode and watch it on the car's big screen while parked.

## Screens

States: E empty, F filled, L loading, X error, P paywalled. "seen" = in the recording; "inferred" = from listing/FAQ/reviews only.

| ID | screen | route / how to reach | purpose | key components | states seen |
| --- | --- | --- | --- | --- | --- |
| S01 | Home (library) | tab 1 | browse all channels by playlist group | large-ish nav title, search field with mic, + (add source), group rows of channel tiles, "Add a Source" CTA | E seen (`S01-home-empty.jpg`); F, L, X inferred (groups, logos, ms latency badge, unavailable channels hidden) |
| S01b | Group list | tap a row title on S01 | every channel in one group, incl. hidden/unavailable ones | channel list, filter | inferred (FAQ #7) |
| S02 | Favorites | tab 2 | quick access to favourited items; local videos | sub-tabs "Favorites" / "Local" (underline segmented), empty state, "Import Now" | E seen for Local (`S02-favorites-local-empty.jpg`); F inferred (drag-to-reorder, 1.1.4) |
| S03 | Discover | tab 3 | entry to browser and the two casting modes | three grouped rows: Browser, Cast to Screen, Cast from an app | F seen (`S03-discover.jpg`) |
| S04 | Pro paywall | full-screen modal; opens on Cast to Screen, Settings > CarTV Pro, on launch | sell Pro | hero photo, 5 benefit rows, plan radio cards (Weekly $3.99 / Lifetime $21.49, badge), green CTA, Terms/Privacy/Restore/Redeem, delayed close X | seen (`S04-paywall-pro.jpg`), skip for clone |
| S05 | Cast to Screen (mirroring) | S03 > Cast to Screen | mirror whole phone to car display | system broadcast picker, status | not seen (paywall blocked it); inferred from listing. Already rebuilt: Torpido "Perde" tab |
| S06 | Cast from an app (DLNA receiver) | S03 > Cast from an app | be a DLNA/UPnP renderer other apps cast to | device illustration "CarTV (iPhone)", "Waiting for an app to cast…", Media Apps list (Disney+, Instagram, Netflix, Prime Video, TikTok, Tubi, YouTube) with external-link icons, DLNA/UPnP footnote, Local Videos: Choose Files / From Photos | waiting seen (`S06-cast-from-app.jpg`); receiving/playing inferred |
| S06b | Per-app cast guide | tap an app on S06 | how to cast from that app | steps / opens app | inferred |
| S07 | Browser | S03 > Browser | in-app web browser with saved favourites and sign-ins | web view, address bar, bookmarks | inferred (listing, reviews: Google OAuth works) |
| S08 | Settings | tab 4 | app settings | grouped list: CarTV Pro; Media › Manage Sources (M3U · Jellyfin · Emby · Xtream · Plex); Preferences › Language; Legal › Privacy, Terms; About › Help & FAQ, Version 1.1.3 (48) | seen (`S08-settings.jpg`) |
| S09 | Manage Sources | S08 > Manage Sources | list, refresh, rename, remove sources | source rows, empty state, "Add a Source" | E seen (`S09-manage-sources-empty.jpg`); F inferred |
| S09b | Add Source | S01 + / S09 "Add a Source" | add M3U (paste link or scan QR), Xtream (server, user, password), Jellyfin/Emby/Plex sign-in | type picker, text fields, QR scanner, validation errors ("Download failed", "Not a valid channel playlist") | inferred (FAQ #6, listing) |
| S10 | Language | S08 > Language | pick UI language | search field, Follow System ✓, Recommended (English, Türkçe), All Languages with flags | seen (`S10-language.jpg`) |
| S11 | Privacy Policy | S08 > Privacy Policy | in-app policy text | long text page | seen (`S11-privacy-policy.jpg`) |
| S12 | Terms of Use | S08 > Terms | opens Apple Standard EULA in Safari view | SFSafariViewController | seen (`S12-terms-eula-safari.jpg`) |
| S13 | Help & FAQ | S08 > Help & FAQ | 10 accordion FAQs + contact | accordion rows, "Still need help? Contact us", "We will reply within 48 hours" | seen (`S13-help-faq.jpg`, `S13b-help-faq-contact.jpg`) |
| S14 | Player | tap a channel/episode/video | full-screen playback | controls overlay, subtitles, audio track, press-and-hold speed, playback-source switch, size (fit/stretch), resume position, audio visualizer for music | inferred (listing, FAQ #9, reviews) |
| S15 | Mini player | while browsing during playback | keep playing while browsing | docked bar, play/pause, expand | inferred |
| S16 | Media server browser | Home for Jellyfin/Emby/Plex sources | libraries → series → seasons → episodes, resume | poster grid/list, episode list | inferred |
| S17 | Car mode / CarPlay | landscape on phone in mount; CarPlay display | oversized controls, one-tap switching, rotary-knob navigation | big tiles, large type | inferred (Pro feature) |
| S18 | Search | S01 search field | search channels/items, voice search, history | results list, recent searches with clear | inferred (1.1.1, 1.1.3) |
| S19 | Local videos | S02 > Local | imported files in folders | folder list, rename, delete, drag-to-sort | E seen (in S02); F inferred (1.1.3–1.1.4) |

Screens: 19 (+3 sub-screens). Seen: 10. Inferred: 12.

## Flows

```
F01 Add an M3U playlist and watch a channel  (core loop)
    S01 (empty) -> "Add a Source" -> S09b choose M3U -> paste URL -> Save -> S01 (filled) -> tap channel -> S14
    happy path clicks: 5 (plus paste)
    edge: URL expired / not #EXTM3U ("Not a valid channel playlist"), download fails, 100k-entry playlist,
          some channels dead (hidden by health check), stream has several sources, provider limits concurrent streams

F02 Mirror the phone to the car display
    S03 -> S05 Cast to Screen -> system broadcast sheet -> Start Broadcast -> switch to another app
    happy path clicks: 4 (CarTV, after paywall). Torpido today: 3 (Perde -> Yansıtmayı Başlat -> Yayını Başlat)
    edge: CarPlay not connected, app suspended, A/V delay (reviews: Mercedes), disconnects after 2 min (developer reply)

F03 Receive a cast from another app (DLNA/UPnP)
    S03 -> S06 (waiting) -> open YouTube/Tubi/... -> tap cast icon -> pick "CarTV (iPhone)" -> S14 plays on car screen
    happy path clicks: 5
    edge: app blocks DLNA or caps quality (footnote), not on same network, local-network permission denied

F04 Connect a Jellyfin/Emby server and resume an episode
    S08 -> S09 -> S09b Jellyfin -> server URL, user, password -> S16 library -> series -> season -> episode -> S14 (resumes)
    happy path clicks: 8
    edge: wrong credentials, server unreachable off-LAN, multi-version items fail to load (review)

F05 Import a local video and play it offline
    S02 -> Local -> "Import Now" -> Files or Photos picker -> pick -> S19 -> tap -> S14
    happy path clicks: 5
    edge: HEVC/MKV/DTS needs software decoder, HDR colour (fixed 1.1.4), large file copy, storage full

F06 Favourite a channel and reorder favourites
    S14 or long-press tile -> favourite -> S02 Favorites -> drag to reorder
    happy path clicks: 3
    edge: channel removed when the playlist refreshes

F07 Search with voice and history
    S01 search -> mic / type -> S18 results -> tap -> S14 ; recent searches -> tap / clear
    happy path clicks: 3

F08 Use car mode on the dashboard mount
    rotate phone to landscape (or open on CarPlay) -> S17 big tiles -> one-tap next/previous entry
    edge: rotary knob / touchpad controllers (Mercedes COMAND), CarPlay search requested by users

F09 Change language          S08 -> S10 -> pick                       clicks: 3
F10 Get help                 S08 -> S13 -> expand FAQ / Contact us    clicks: 3
F11 Buy Pro                  S04 -> plan -> Buy                       skip (no payments in the clone)
```

## Components

| component | variants | states | used on |
| --- | --- | --- | --- |
| Tab bar | 4 tabs: Home, Favorites, Discover, Settings | selected, default | all top-level |
| Grouped list row | icon + title + subtitle + chevron; title + value + chevron; plain | default, pressed, disabled | S03, S06, S08, S10, S13 |
| Empty state | icon + title + body + pill button | — | S01, S02, S09 |
| Primary pill button | green filled, small (empty states), large (paywall) | default, pressed, loading | S01, S02, S04, S09 |
| Search field | with mic button | empty, typing, listening | S01, S10, S18 |
| Underline segmented tabs | 2 segments | selected, default | S02 |
| Channel tile | logo, name, latency badge (ms) | loading, playing, unavailable (hidden) | S01, S01b, S17 |
| Group row header | tappable title + "see all" | — | S01 |
| Plan card | radio, title, subtitle, price, badge | selected, default | S04 (skip) |
| Accordion row | question + chevron | collapsed, expanded | S13 |
| Language row | flag + name + checkmark | selected, default | S10 |
| Cast-target illustration | device frame + name + waiting text | waiting, receiving | S06 |
| External-app row | external-link icon + app name | default | S06 |
| Player overlay | play/pause, scrubber, subtitles, audio track, speed, source switch, size | visible, auto-hidden, buffering, error | S14 |
| Mini player bar | artwork, title, play/pause | playing, paused | S15 |
| Source form | M3U (URL, QR), Xtream (server/user/pass), media server sign-in | empty, validating, error, saved | S09b |
| QR scanner | camera view | permission prompt, scanning, denied | S09b |
| Safari view | — | — | S12, S07(?) |

## Inferred data model

```
Source        id, type (m3u | xtream | jellyfin | emby | plex), name (renamable), url,
              username?, secret? (Keychain), last_refreshed_at, status (ok | failed), created_at
              evidence: S08 "M3U · Jellyfin · Emby · Xtream · Plex", S09, FAQ #2 #4 #6, listing "refresh, rename, remove"
              confidence: high

Group         id, source_id, title (from group-title), position
              evidence: listing "reads group-title", "filter by groups", FAQ #7 (row titles)
              confidence: high

Channel       id, source_id, group_id, name, logo_url (tvg-logo), tvg_id?, stream_urls[] (one or more playback sources),
              health (ok | down | unknown), latency_ms?, last_checked_at
              evidence: listing "tvg-logo", FAQ #7 (background checks), FAQ #9 ("another playback source"), review (green ms badge)
              confidence: medium (multi-source and latency are guesses at the shape)

MediaItem     source_id, remote_id, kind (movie | series | season | episode), parent_remote_id?, index?, title, image_url
              — fetched live from the Jellyfin/Emby/Plex API, cached
              evidence: listing "libraries, seasons and episodes, sorted automatically"
              confidence: medium

LocalVideo    id, file_name (in app container), display_name (renamable), folder, sort_order, imported_at, duration
              evidence: S02 Local, S06 "Choose Files / From Photos", 1.1.3 rename, 1.1.4 drag-sort / delete
              confidence: high

Favorite      id, item_ref (channel | media item | local video), sort_order
              evidence: listing "mark favourites", 1.1.4 drag-to-reorder
              confidence: high

PlaybackPosition  item_ref, position_s, duration_s, updated_at
              evidence: "remembers where you left off", privacy policy "playback positions"
              confidence: high

SearchQuery   text, searched_at
              evidence: 1.1.3 "search history with quick re-search and clear"
              confidence: high

Bookmark      url, title, created_at   (browser favourites; sign-in cookies live in WKWebsiteDataStore)
              evidence: S03 "Browse websites and save your favorites", FAQ #2
              confidence: medium

Preferences   language, visualizer_style, fill_mode, preferred_subtitle_language?
              evidence: S10, 1.1.3 visualizer "selection memory", review "size controls"
              confidence: medium
```

Relationships: Source 1-n Group, Group 1-n Channel, Source 1-n MediaItem; Favorite and PlaybackPosition point at Channel | MediaItem | LocalVideo. All on-device (no accounts, no server).

## Feature matrix

See `features.csv`. Must: 9, should: 16, could: 14, skip: 8.

## Out of scope (cannot or should not be cloned)

- Channels and content: CarTV ships none and neither will Torpido. The owner supplies their own playlists/servers and needs the right to use them.
- Pro paywall, weekly/yearly/lifetime IAP, redemption codes, restore purchases: personal app, no payments.
- Creator/referral partner program.
- Ads attribution and analytics (Adjust, Meta SDK, Umeng, FirstFew) and the announcements server (api.cartv.app): PRODUCT.md says no tracking.
- CarTV's name, hero photo, copy, icons and green brand: Torpido has its own (DESIGN.md).
- 22 UI languages: Turkish (+ English fallback) is enough for one owner.
- CarPlay video: needs Apple's CarPlay entitlement (the same blocker as mirroring). Built, but cannot run in the car until Apple grants it.

## Size

Screens 19 (+3 sub), flows 11 (10 to build), entities 10.
Hard parts:
1. Playback breadth: MKV/HEVC/DTS and embedded subtitle tracks need a software decoder (VLCKit or an FFmpeg-based player) beside AVPlayer. Large binary, LGPL licence (fine for personal use).
2. DLNA/UPnP renderer (F03): SSDP discovery, device description XML, AVTransport/RenderingControl SOAP. Plus the Local Network permission.
3. Big M3U playlists: streaming parse of 100k+ entries, storage, search, and background health checks without hammering the provider.
4. Media-server APIs: Jellyfin/Emby (similar REST), Plex (plex.tv sign-in, different API).
5. Car mode on CarPlay: video in the CarPlay window depends on the entitlement; rotary-knob focus navigation.

Size: L (a quarter) for the whole app. The core loop alone (M3U → Home → Player → favourites/resume, F01 + F06) is M (a few weeks).
