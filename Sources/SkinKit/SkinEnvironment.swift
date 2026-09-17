import SwiftUI

private struct SkinEnvironmentKey: EnvironmentKey {
    static let defaultValue: Skin = .classic
}

public extension EnvironmentValues {
    /// The skin every view reads. Set once at the root; everything below re-renders when
    /// a skin file changes on disk.
    var skin: Skin {
        get { self[SkinEnvironmentKey.self] }
        set { self[SkinEnvironmentKey.self] = newValue }
    }
}

public extension View {
    func skin(_ skin: Skin) -> some View {
        environment(\.skin, skin)
    }
}

public extension Skin {
    var displayFont: Font { fonts.display.font }
    var readoutFont: Font { fonts.readout.font }
    var bodyFont: Font { fonts.body.font }
}
