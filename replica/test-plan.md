# Test plan: Torpido

Native iOS, so Playwright and axe are replaced by:
- **Unit and integration tests:** XCTest, `Tests/`, 46 cases.
- **UI tests:** XCUITest, `UITests/`.
- **Accessibility:** `performAccessibilityAudit()`, the iOS counterpart of an axe scan.

All of it runs on GitHub Actions (iPhone simulator) with DEBUG launch arguments: `-TorpidoReset 1` (empty state) and `-TorpidoSeed 1` (synthetic channels on Apple's HLS test streams). Only Torpido is tested. CarTV and its servers are never touched.

Legend:
- **U:** unit/integration test
- **UI:** XCUITest
- **M:** manual on a real iPhone or car
- **–:** feature not built yet

## F01 Add an M3U playlist and watch a channel
- H1: paste a link, Add, the groups appear on Ana Sayfa, tap a tile and it plays. U (parser, importer); UI (play part); CI screenshot shows HLS playing.
- E1: empty input, so Ekle stays disabled. M
- E2: 20,000-entry playlist imports in one transaction. U
- E3: accents and Turkish İ/ı in names and groups. U (`TurkishFold`, importer)
- E4: duplicate names in one group. U (`#2` stable keys)
- E5: BOM, CRLF, quoted commas, `#EXTGRP`. U
- E6: refresh keeps favourites and channel ids. U
- E7: offline when adding shows "Liste indirilemedi". M
- N1: the text is not a URL, so the message appears and nothing is added. UI
- N2: the page is HTML, not `#EXTM3U`, so "kanal listesi değil". U (parser)
- N3: a link with a password: the password stays in the Keychain, never in the DB. U

## F02 Mirror the phone to the car
- H1: Perde, Yansıtmayı Başlat, Yayını Başlat, and the car shows the phone. M (needs the CarPlay entitlement and the car)
- E1: CarPlay not connected, so the perde says "Arabaya bağlı değil". CI screenshot
- E2: largest Dynamic Type, so the button wraps whole words. CI screenshot
- N1: frame stream corrupted or too large, so the connection is dropped. U (`FrameDecoder`)

## F03 Receive a DLNA cast: –

## F04 Jellyfin: sign in, browse, resume
- H1: sign in, open a library, open a series, open an episode, it plays. U (stub server); M (real server)
- E1: resume position is read from the server and progress is reported. U
- N1: wrong password gives "Kullanıcı adı ya da şifre yanlış". U
- N2: the token never reaches the DB. U

## Xtream (part of F01 for providers)
- H1: login, categories, channels, play. U (stub panel); M (real account)
- E1: ids sent as numbers or strings; empty names; unknown category. U
- E2: the panel only allows `ts`, so `.ts` URLs are used. U
- E3: a channel moves category and keeps its favourite. U
- N1: wrong password, expired account. U
- N2: the password never reaches the DB; the play URL is built at play time. U

## F05 Local videos: –

## F06 Favourite a channel
- H1: long-press a tile, Favorilere ekle, it is on Favoriler. UI
- E1: toggle twice removes it. U
- E2: removing a source removes its favourites. U
- E3: order follows the order added. U

## F07 Search: –

## F08 Car mode: –

## F09 / F10 Language, help
- No language picker (skip). Help is the Ayarlar "Nasıl çalışır" section: CI screenshot.

## Every screen
- Accessibility audit on each tab (contrast, labels, hit regions, Dynamic Type). UI
- Dark appearance and largest text size: CI screenshots.
- Keyboard only: not applicable on iPhone. VoiceOver labels are checked by the audit.
