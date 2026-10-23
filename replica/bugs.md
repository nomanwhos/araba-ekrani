# Bugs: Torpido

Found by the CI test suite (unit, XCUITest and accessibility audit on the iPhone simulator). Only reproduced bugs are listed. Severity uses the replica scale: S1 critical … S4 cosmetic.

| ID | severity | status | fixed in |
| --- | --- | --- | --- |
| BUG-001 | S3 | fixed | d686875 |
| BUG-002 | S4 | fixed | this commit |

## BUG-001: VoiceOver reads the logo initials before the channel name
- **Severity:** S3. Visibly wrong for screen-reader users, and VoiceOver users have a workaround.
- **Steps:**
  1. Launch with seed data.
  2. Turn VoiceOver on.
  3. Focus the "Haber 24" tile on Ana Sayfa.
- **Expected:** "Haber 24, 180 ms, button".
- **Actual:** "H2, Haber 24, …". The placeholder initials are read first. When the channel is a favourite, "Favori" is read before the name.
- **Evidence:** UI tests `testFavouriteFromHomeAppearsInFavourites` and `testPlayerShrinksToMiniPlayer` could not find a tile whose label starts with its name (CI run 39862149436).
- **Fix:** the logo and initials are hidden from VoiceOver, and "Favori" moved to the accessibility value. Both tests pass since d686875.

## BUG-002: latency badge is clipped on Home tiles
- **Severity:** S4.
- **Steps:**
  1. Launch with seed data.
  2. Look at the "Haber 24" tile.
- **Expected:** "180 ms" shown in full.
- **Actual:** the accessibility audit reports "Text clipped" on the badge ("Gecikme 180 milisaniye" and "Gecikme 720 milisaniye"; CI run 39862746763).
- **Fix:** the badge text keeps its ideal size (`fixedSize`, one line).

## To check (not reproduced as a user-facing bug)
- **Contrast through the tab bar:** the audit flags contrast on content that has scrolled under iOS 26's translucent tab bar: the Belgesel row, and the last notes in Ayarlar. The same elements in open space pass. This is likely the audit measuring through the glass. The test now skips elements under the tab bar; check by eye on a real phone. **Checked on the owner's iPhone 2026-10-23: fine, closed.**
- **Unattributed contrast findings in Ayarlar:** two "Contrast failed" findings come with no element attached (CI run 39864005136). They most likely come from the same notes under the tab bar that run 39862746763 named. The test ignores findings that have no element; check Ayarlar by eye on a real phone. **Checked on the owner's iPhone 2026-10-23: fine, closed.**
- **Search field placeholder:** "Text clipped" and "contrast nearly passed" on the "Kanal ara" placeholder (CI run 39875181977). This is the system `.searchable` field, whose placeholder style is iOS's. The audit skips search fields; check by eye whether the placeholder is cut off at large text sizes. **Checked on the owner's iPhone 2026-10-23: fine, closed.**
- **Dynamic Type in Perde:** "partially unsupported" on the system section header ("Durum") and footer of the Perde list. The accessibility-size screenshot shows them growing. Check whether they stop at a maximum size on a device.

2026-10-23: the audit flagged contrast on Perde's 'Uygulamadan gönder' row once the row sat just above the tab bar. Row text now uses Theme.text explicitly, and the audit also skips the 44 pt scroll-edge band above the tab bar (to check: confirm on a device that the row reads clearly when scrolled to that spot).
