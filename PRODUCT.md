# Product

<!-- impeccable:product-schema 1 -->

## Platform

ios

## Stack

delegated: native Swift + SwiftUI, with a CarPlay scene and a ReplayKit Broadcast Upload Extension. Chosen because the CarPlay window and system-wide screen capture are native-only; Expo Go cannot reach either. The owner works on Windows with no Mac, so builds run on a cloud macOS runner (e.g. GitHub Actions) and install to the iPhone via a paid Apple Developer account. No money is spent on the account or build minutes without the owner's explicit OK.

## Users

One person: the owner, using their own iPhone and their own car's CarPlay display. Used as a passenger or while parked (waiting, charging stop, camping), never while driving.

## Product Purpose

A personal-use app, modeled on the function of CarTV (App Store id6800211040), that mirrors the iPhone screen onto the car's CarPlay display so any app on the phone (video apps included) can be watched on the car screen. Success: the owner opens the app, taps mirror on the phone, and sees the phone screen on the car display with acceptable delay.

## Positioning

Built for one owner and one car rather than for the store: no account, no subscription, no paywall, no tracking, and only the features the owner actually uses.

## Operating Context

- The app shows up in two places once installed: on the iPhone and as an icon on the CarPlay home screen.
- Both sides have a "Cast" section. The owner opens Cast, then starts mirroring from the phone ("mirror from phone"), which starts the system screen broadcast; the car display then shows the phone screen.
- Typical scene: car parked, phone in a dashboard mount or in hand, car display large and lit.

## Capabilities and Constraints

- Core v1 capability: whole-screen mirroring of the iPhone to the CarPlay display.
- Hard dependency: Apple must grant a CarPlay entitlement to the owner's developer team. Reference implementations use the CarPlay navigation entitlement (`com.apple.developer.carplay-maps`) to get a drawable CarPlay window. Approval is not guaranteed and is the main project risk. iOS 27 adds a CarPlay video entitlement, but it only works in cars that support the video-in-car feature.
- Screen capture runs through a ReplayKit broadcast extension, handing frames to the main app, which renders them in the CarPlay window. Apple may be moving this to ScreenCaptureKit; verify current docs before building.
- Expected limitation: some audio/video delay on the car side (also reported by CarTV users).
- Passenger and parked use only; the app must say so.
- Not distributed on the App Store; personal install only.
- Car: 2024 Hyundai Sonata. iPhone runs iOS 27. As of 2026-10, no automaker (Hyundai included) has announced support for the iOS 27 CarPlay video-in-car feature, Tested by the owner on 2026-10-16: no AirPlay target for the CarPlay display appears, so the car does not support video-in-car. The only route is the CarPlay navigation entitlement.
- Name: Torpido (chosen by the owner 2026-10-16).
- Open decisions: whether CarPlay in the car is wired or wireless; whether touches on the car display should control the phone.
- Reference app structure (from the owner's screen recording of CarTV 1.1.3, 2026-10-16), for function only: four tabs, Home / Favorites (sub-tabs Favorites and Local, with "Import" for device videos) / Discover (Browser, Cast to Screen = mirror the iPhone screen, Cast from an app = receive casts from apps with a built-in Cast button over the local network) / Settings (Manage Sources: M3U, Jellyfin, Emby, Xtream, Plex; Language; Privacy, Terms; Help & FAQ; Version). CarTV also has a Pro paywall (weekly or lifetime); this app has none.
- Out of scope for v1: M3U/IPTV playback, Jellyfin/Emby, local video library. These may come later.

## Brand Commitments

Name: Torpido. CarTV's name, logo, and visuals are not to be reused; the app gets its own identity.

## Evidence on Hand

- Reference: CarTV App Store listing (feature list and user reviews), and the open-source CarPlayTV project on GitHub (unvetted).
- No playlists, servers, or content sources on hand.

## Product Principles

1. Mirroring works first; everything else waits.
2. One tap from opening the app to the car screen showing the phone.
3. Safety is built into the product: passenger and parked use only.
4. Everything stays on the phone: no account, no analytics, no network calls the owner didn't ask for.
