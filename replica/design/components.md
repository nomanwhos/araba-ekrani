# Torpido components (v2)

Native iOS, so "component" means a SwiftUI view or a system control. Rules carried from DESIGN.md and ios.md:
- System controls first. Build our own only where the system has nothing (bulbs, perde, channel row).
- Tokens only (`Theme.*`, generated from `tokens.json`), never raw colours.
- Amber (`Theme.accent`) is for the marquee name, the bulbs, the one primary action per screen and on-states.
- Every tap target is at least 44pt. Text uses Dynamic Type styles. Everything works with VoiceOver.

What was taken from CarTV: the roles, the screen structure and how each control behaves (recon S-IDs). What was not taken: green, white light-mode lists, the paywall photo, its copy and its icons. Icons are SF Symbols, and all copy is new Turkish text.

Built primitives live in `App/Design/Components/` and are shown together in `DesignCatalogView` (DEBUG, `-TorpidoCatalog 1`, CI screenshot `design-catalog.png`).

```
Tab bar                                         system TabView
  tabs      Ana Sayfa (house), Favoriler (star), Perde (play.rectangle), Ayarlar (gearshape)
  states    selected (accent tint), default
  a11y      system
  used on   all top-level (S01, S02, S03/Perde, S08)
  note      CarTV's "Discover" becomes Perde, which already holds mirroring; browser and DLNA join it later

Primary button                                  system .borderedProminent .controlSize(.large)
  tokens    bg accent, text on-accent, radius pill, font headline
  states    default, pressed (system), disabled (system dim), loading (ProgressView replaces the icon, label stays)
  a11y      the label names the action; at accessibility sizes the icon drops and the words wrap whole
  rule      one per screen
  used on   Perde, S09b Save, S01/S02/S09 empty states (small size)

EmptyState                                      built: EmptyState.swift
  parts     SF Symbol (text-muted, hidden from VoiceOver), title (headline), message (subheadline, text-muted), optional small primary button
  states    with action, without action
  copy      the title names what is missing, the message says how to fix it; written fresh
  used on   S01 "Henüz kanal yok", S02 "Favori yok" / "Video yok", S09 "Kaynak yok", S18 "Sonuç yok"

ChannelRow                                      built: ChannelRow.swift
  parts     ChannelLogo 40pt (scaled) on a bg tile with radius tile 10; name (body, 2 lines); group (footnote); HealthBadge; star when favourite
  states    default, playing (name semibold accent + .isSelected), favourite, health unknown / ok / down
  a11y      one combined element with the .isButton trait; badge and star read as words
  actions   tap = play; swipe leading = favourite; context menu = favourite, kaynağı değiştir, bilgileri
  used on   S01b, S02, S18, CarPlay list

ChannelLogo                                     built (in ChannelRow.swift)
  states    loading / no logo = initials (tr_TR uppercase) on a bg tile; loaded = tvg-logo, aspect-fit, 4pt inset
  note      the logos belong to channel owners and are fetched from the owner's playlist at runtime; none ship in the app

HealthBadge                                     built (in ChannelRow.swift)
  states    unknown = nothing; ok = "N ms" in monospaced digits, success < 300, warning < 1000, otherwise danger; down = wifi.slash in danger
  a11y      "Gecikme N milisaniye" / "Yayın şu an kapalı"

GroupHeader                                     built: GroupHeader.swift
  parts     title (title3 bold), count (monospaced, text-muted), chevron
  states    default, pressed (system plain), long title truncates to one line
  a11y      one button: "<title>, N kanal", hint "Gruptaki tüm kanalları gösterir"
  used on   S01 above each group's horizontal row

Channel tile (Home rows)                        to build with S01
  parts     logo 64pt on a surface tile with radius tile, name below (footnote, 2 lines), HealthBadge in the corner
  states    default, focused (system hover effect for rotary/keyboard), playing (accent 2pt ring)
  used on   S01 horizontal rows, S17 car mode (scaled up)

SourceKindLabel                                 built: SourceKindLabel.swift
  parts     symbol (text-muted), kind title, one-line detail
  used on   S09b kind picker, S09 source rows (with status and last refresh)

Source form                                     to build with S09b: system Form
  fields    M3U: URL (keyboard .URL, paste button, QR button) + optional name. Xtream: server, username, password (SecureField). Jellyfin/Emby: server, username, password. Plex: "Plex ile giriş" (PIN in Safari view).
  states    empty (Save disabled), validating (ProgressView in Save), error (footer in danger: "Liste indirilemedi" / "Bu bir kanal listesi değil (#EXTM3U yok)" / "Kullanıcı adı ya da şifre yanlış"), saved (dismiss + Home shows import progress)
  a11y      labels on every field; error is announced (AccessibilityNotification.Announcement)

QR scanner                                      to build with S09b: DataScannerViewController (VisionKit)
  states    permission prompt, scanning, found (haptic + fills URL), denied (explains, opens Settings)

Segmented switch                                system Picker .segmented
  used on   S02 "Favoriler | Videolar" (CarTV's underline tabs are replaced by the platform control)

Search                                          system .searchable
  states    empty (recent searches with "Temizle"), typing, results, no results (EmptyState), listening (mic in the field, Speech framework)
  used on   S01 (scoped to all sources), S18

Player                                          system AVPlayerViewController, wrapped
  added     stream switch (when a channel has more than one URL), fit/fill (videoGravity), A/V offset (our fix), favourite
  states    loading, playing, paused, buffering, error ("Bu yayın açılmadı" + "Diğer kaynağı dene" when one exists), live (no scrubber)
  a11y      system player controls; our buttons labelled

MiniPlayerBar                                   built: MiniPlayerBar.swift
  parts     logo, title (subheadline semibold), subtitle (footnote), play/pause 44pt in accent
  states    playing, paused, buffering (ProgressView instead of the icon)
  a11y      two controls: the bar ("Oynatıcıyı açar") and play/pause
  used on   above the tab bar on S01, S02, S08 while something plays (S15)

Accordion                                       system DisclosureGroup
  used on   S13 if FAQ grows past the current "Nasıl çalışır" section

Marquee, Bulb, Perde                            built in v1 (MarqueeScreen.swift)
  change    unlit bulb rim raised from 35% to 50% accent so it reaches 3.33:1 on bg (contrast report)

Car mode tile                                   to build with S17
  parts     ChannelLogo 96pt, name (title3), large next/previous controls
  states    default, focused (rotary knob), playing
  rule      landscape only, min target 60pt

CarPlay list                                    system CPListTemplate / CPSearchTemplate
  sections  Favoriler, Son izlenenler, groups; tap plays in the CPWindow
```

## Contrast report

`python3 contrast.py replica/design/tokens.json`, 2026-10-20: 18 pairs, 0 failing AA.
- The only first-run failure was the unlit bulb rim, at 2.22:1 on bg (UI needs 3:1).
- It is fixed in the tokens (`accent-unlit-rim` #846230, 3.33:1) and in `MarqueeScreen.swift`.
- Translucent system colours are measured at their composited value (see `_composited` in `tokens.json`).
