---
name: Torpido
description: A drive-in screen in the dashboard; mirrors the iPhone to the CarPlay display.
colors:
  marquee-amber: "#FFB13B"
  night: "#0A1324"
  night-raised: "#16223A"
  perde-dark: "rgba(0, 0, 0, 0.4)"
  projector-white: "#F7F5ED"
  projector-falloff: "#CCC9C2"
typography:
  display:
    fontFamily: "SF Pro Expanded, -apple-system, system-ui, sans-serif"
    fontSize: "34px"
    fontWeight: 900
    lineHeight: 1
    letterSpacing: "normal"
  title:
    fontFamily: "SF Pro, -apple-system, system-ui, sans-serif"
    fontSize: "20px"
    fontWeight: 700
  headline:
    fontFamily: "SF Pro, -apple-system, system-ui, sans-serif"
    fontSize: "17px"
    fontWeight: 600
  body:
    fontFamily: "SF Pro, -apple-system, system-ui, sans-serif"
    fontSize: "17px"
    fontWeight: 400
  subheadline:
    fontFamily: "SF Pro, -apple-system, system-ui, sans-serif"
    fontSize: "15px"
    fontWeight: 400
  footnote:
    fontFamily: "SF Pro, -apple-system, system-ui, sans-serif"
    fontSize: "13px"
    fontWeight: 400
  car-hint:
    fontFamily: "SF Pro, -apple-system, system-ui, sans-serif"
    fontSize: "20px"
    fontWeight: 600
rounded:
  perde: "14px"
  capsule: "999px"
  bulb: "50%"
spacing:
  hairline: "4px"
  caption: "6px"
  marquee: "14px"
  perde-inset: "20px"
  car-margin: "24px"
components:
  button-primary:
    backgroundColor: "{colors.marquee-amber}"
    textColor: "{colors.night}"
    typography: "{typography.headline}"
    rounded: "{rounded.capsule}"
    height: "44px"
  perde-idle:
    backgroundColor: "{colors.perde-dark}"
    textColor: "#FFFFFF"
    rounded: "{rounded.perde}"
    padding: "20px"
    height: "198px"
  perde-live:
    backgroundColor: "{colors.projector-white}"
    textColor: "{colors.night}"
    rounded: "{rounded.perde}"
    padding: "20px"
    height: "198px"
  list-row:
    backgroundColor: "{colors.night-raised}"
    typography: "{typography.body}"
  bulb:
    backgroundColor: "{colors.marquee-amber}"
    rounded: "{rounded.bulb}"
    size: "12px"
---

# Design System: Torpido

## Overview

**Creative North Star: "The Drive-In Marquee"**

Torpido is a drive-in cinema parked in the dashboard. The night sky is the ground, a row of amber marquee bulbs sits over a single 16:9 screen (the perde), and the screen lights projector-white only when the picture is actually running. The whole state of the product reads off that one composition: bulbs dark while waiting for the car, steady when ready, chasing while live.

Around the marquee, everything is stock iOS: SF Pro, grouped lists, SF Symbols, the system tab bar and the system bordered-prominent button. The world lives in color, one signature component and one display face; it does not reinvent controls. Dark is the scene, not a theme: the app forces the dark color scheme because it is used in a parked car, mostly in the evening.

Density is low and the phone screen carries one action. The car display repeats the marquee (bulbs, name, one instruction) and otherwise hands the whole surface to the mirrored picture.

**Key Characteristics:**
- Night-navy ground with a slightly lifted navy for list rows; no light mode.
- Marquee amber is scarce and meaningful: name, bulbs, the one primary button, on-state status.
- One signature component: the marquee (name, bulb row, perde) whose bulbs encode state.
- Projector-white appears only on the live perde.
- Native iOS everywhere else: SF Pro, grouped lists, SF Symbols, system tab bar.

## Colors

A two-tone night palette, navy ground and marquee amber, with projector-white reserved for the moment the show is on.

### Primary
- **Marquee Amber**: the bulb-glass color of a drive-in marquee. Used on the "TORPİDO" name, every bulb (lit at full strength, unlit at 14% fill with a 35% rim), the single primary button fill, the selected tab, and the value and icon of a status row only while that status is on.

### Neutral
- **Night**: the page ground behind every list, the CarPlay idle background, and the label color on amber and on the live perde (dark text on light, never white on amber).
- **Night Raised**: grouped list row background on both tabs; one tonal step up from Night, never a card with a shadow.
- **Perde Dark**: the unlit screen, black at 40% over Night, outlined by a 1px white 10% hairline.
- **Projector White / Projector Falloff**: a radial gradient (brightest at center, radius 10 to 260pt) filling the perde only while live; the hairline drops to 0 when lit.
- Secondary text and icons use the system `.secondary` label color; errors use system red.

### Named Rules
**The Marquee Amber Rule.** Amber belongs to the marquee name, the bulbs, the one primary button and on-state status values and icons. Informational, step and note icons use `.secondary`. If amber appears on something that is not lit, live or the action, it is wrong.

**The Projector Rule.** Projector-white lights the perde only while a broadcast is live. No other surface is ever light.

**The Dark-Text-On-Light Rule.** Text on amber or on the lit perde is Night, not white.

## Typography

**Display Font:** SF Pro Expanded, Black weight (the marquee name only)
**Body Font:** SF Pro (system), at Dynamic Type text styles

**Character:** One wide, heavy marquee word over plain system text. The contrast between the expanded black name and the ordinary list type is the whole typographic idea.

### Hierarchy
- **Display** (Black 900, Large Title 34pt, expanded width, one line, scales down to 60%): "TORPİDO" in amber, leading-aligned, on the phone marquee and the CarPlay idle screen. Nowhere else.
- **Title** (Bold 700, Title 3, 20pt): perde caption title ("Perde hazır", "Yayında"), with a Title-size SF Symbol above it.
- **Headline** (Semibold 600, 17pt): the primary button label.
- **Body** (Regular 400, 17pt): list rows, status rows, settings steps and notes.
- **Subheadline** (Regular 400, 15pt, 80% opacity): perde caption detail, centered.
- **Footnote** (Regular 400, 13pt, secondary): system section headers and footers, including the passenger-and-parked safety line.
- **Car Hint** (Semibold 600, 20pt, white at 78%): the one centered instruction on the CarPlay idle screen.

### Named Rules
**The One Expanded Word Rule.** SF Pro Expanded Black is used for the marquee name and nothing else. Every other string is plain SF Pro at a system text style.

**The Dynamic Type Rule.** Phone type uses text styles and grows; bulbs scale with `@ScaledMetric` relative to body; the perde grows taller instead of truncating; at accessibility sizes the primary button drops its icon so the words wrap whole.

## Layout

A single vertical column inside an inset grouped list on the Night ground. The Perde tab's first section is transparent and separator-less and holds the marquee and the button edge to edge within the list's content width; status rows follow in a Night Raised section with a "Durum" header and the safety footer. The navigation bar is hidden on Perde (the marquee carries the name); Ayarlar keeps a standard large title.

Marquee rhythm: name, 14pt gap (supplied by the bulb row's glow padding), bulb row, 4pt, perde, 20pt, button. The perde has a 198pt minimum height (16:9 of the narrowest current iPhone content width) and 20pt inner padding; its caption stacks at 6pt. Eleven bulbs spread across the full width with flexible spacers. The primary button is full width, at least 44pt tall.

CarPlay idle: a centered vertical stack (bulbs, name, hint) within the safe area, 24pt minimum side margins, 14pt stack spacing with 24pt after the name. Live, the mirrored frame fills the display, aspect-fit with black bars or aspect-fill per the "fill the screen" setting.

## Elevation & Depth

Flat with tonal layering. Depth comes from Night to Night Raised and from light itself: the bulbs glow and the live perde is lit. Surfaces carry no drop shadows.

### Named Rules
**The Light Is The Only Lift Rule.** Nothing is raised by shadow; things are lit. Bulb glow on the phone is a radial amber gradient (55% at the core falling to 0 at size/2 + 0.6 x size), drawn as a gradient rather than `.shadow` so list rows never clip it into a band.

## Shapes

Continuous (squircle) rounded rectangles at 14pt for the perde; the system capsule for the primary button; system inset-grouped radii for list sections; perfect circles for bulbs, each lit bulb carrying a small white filament highlight (32% of its diameter, 85% opacity) offset toward the top left. Hairlines are 1px and only on unlit things: the dark perde edge and unlit bulb rims.

## Components

### Buttons
- **Shape:** system capsule (`.borderedProminent`, `.controlSize(.large)`).
- **Primary:** Marquee Amber fill with Night headline label and leading SF Symbol (`play.fill` / `stop.fill`), full width, min height 44pt. Label reads "Yansıtmayı Başlat" or "Yansıtmayı Durdur".
- **States:** system pressed treatment; at accessibility text sizes, title only.
- **Secondary:** none. There is one button per screen.

### Lists / Rows
- **Background:** Night Raised rows on the Night ground (`scrollContentBackground(.hidden)`).
- **Status row:** SF Symbol + title on the left, value on the right; icon and value Marquee Amber when on, `.secondary` when off.
- **Step / Note rows:** `.secondary` SF Symbols (`1.circle.fill`, `speaker.wave.2`, `timer`, `hand.tap`) with body text.
- **Toggle:** system toggle, tinted by the accent.

### Navigation
- System tab bar with two tabs, "Perde" (`play.rectangle`) and "Ayarlar" (`gearshape`); the selected tab takes the accent.

### The Marquee (signature)
Name, bulb row, perde, stacked. Three stages:
- **Waiting for car:** bulbs unlit; perde dark with hairline; white caption, `car` symbol, "Arabaya bağlı değil".
- **Ready:** bulbs steadily lit; perde dark; `play.rectangle`, "Perde hazır".
- **Live:** bulbs chase (every third lit, advancing every 0.14s; steady when Reduce Motion is on); perde fades to projector-white over 0.4s ease-out; Night caption, `dot.radiowaves.left.and.right`, "Yayında".
The bulb row is hidden from VoiceOver; the bulbs and perde combine into one accessibility element; the name is a header.

### CarPlay Idle Screen
Night ground, a row of lit amber bulbs, "TORPİDO" in the display face at 34pt, and one Car Hint instruction. It disappears entirely when frames arrive.

## Do's and Don'ts

### Do:
- **Do** keep Marquee Amber to the name, bulbs, the single primary button and on-state status (The Marquee Amber Rule).
- **Do** put Night text on amber and on the lit perde.
- **Do** sit every list on Night with Night Raised rows via the shared night ground.
- **Do** let state show in the bulbs first: unlit, steady, chasing.
- **Do** use system text styles, SF Symbols and system controls; let type scale and the perde grow.
- **Do** respect Reduce Motion: the chase becomes a steady row.

### Don't:
- **Don't** tint informational, step or note icons amber; they are `.secondary`.
- **Don't** light any surface except the live perde with projector-white.
- **Don't** use SF Pro Expanded or Black weight for anything but the marquee name.
- **Don't** add a second filled button to a screen.
- **Don't** add a light appearance; the app is dark by scene.
- **Don't** lift surfaces with drop shadows; glow belongs to bulbs and is drawn as a gradient on the phone.
