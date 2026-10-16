/*
 THESIS: The Perde tab is a drive-in screen. One 16:9 perde under a marquee
 bulb row shows the whole state at a glance (bulbs off, steady, chasing);
 it refuses the settings-list cast page.
 OWN-WORLD: night-sky navy ground ("Night", rows "NightRaised"), marquee amber
 tint ("AccentColor") on the bulbs and the single primary button, the perde lit
 projector-white only while live. SF Pro throughout; SF Expanded Black for the
 marquee name only. System tab bar, grouped lists, SF Symbols.
 STORY: the passenger sees whether the car is connected, taps one button,
 chooses Start Broadcast, then switches to the app they want to watch.
 FIRST VIEWPORT: large title Torpido; bulb row and perde at full width; the
 full-width amber "Yansıtmayı Başlat" right under the perde; status rows below.
 FORM: drive-in cinema, owner's choice (my list #1 over the assigned #7), seed 9b151894.
 FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
 */
import SwiftUI

struct RootView: View {
    enum TabID: Hashable {
        case perde, settings
    }

    @State private var selection: TabID = Self.initialTab

    var body: some View {
        TabView(selection: $selection) {
            Tab("Perde", systemImage: "play.rectangle", value: TabID.perde) {
                PerdeView()
            }
            Tab("Ayarlar", systemImage: "gearshape", value: TabID.settings) {
                SettingsView()
            }
        }
        // Used in a parked car, mostly in the evening: dark is the scene, not a theme.
        .preferredColorScheme(.dark)
    }
}

private extension RootView {
    static var initialTab: TabID {
        #if DEBUG
        DebugLaunchState.initialTab
        #else
        .perde
        #endif
    }
}

extension View {
    /// The night ground every list in Torpido sits on.
    func nightGround() -> some View {
        scrollContentBackground(.hidden)
            .background(Color("Night"))
    }
}
