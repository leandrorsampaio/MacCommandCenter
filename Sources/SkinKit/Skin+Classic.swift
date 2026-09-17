import SwiftUI

public extension Skin {

    /// The built-in default, and the base every other skin layers on top of.
    ///
    /// Grey chassis, green LCD, 2px bevels — the 1997 shape. Fonts are Geneva and Monaco
    /// because both ship with every Mac, so the default skin never depends on a download.
    /// A skin that wants a true pixel typeface ships the file and names it in `fonts`.
    static let classic = Skin(
        id: "classic-97",
        name: "Classic '97",
        author: "Mac Command Center",
        notes: "The grey-and-green original.",
        isBuiltIn: true,
        folderURL: nil,
        colors: SkinColors(
            panel: SkinRGBA(hex: "#3B3B42")!,
            panelHighlight: SkinRGBA(hex: "#6E6E78")!,
            panelShadow: SkinRGBA(hex: "#17171B")!,
            titlebarTop: SkinRGBA(hex: "#4A4A54")!,
            titlebarBottom: SkinRGBA(hex: "#33333B")!,
            titlebarText: SkinRGBA(hex: "#B9B9C4")!,
            titlebarButtonFace: SkinRGBA(hex: "#2B2B32")!,
            sectionLabel: SkinRGBA(hex: "#9A9AA6")!,
            text: SkinRGBA(hex: "#D2D2DC")!,
            textDim: SkinRGBA(hex: "#9A9AA6")!,
            buttonFace: SkinRGBA(hex: "#45454E")!,
            buttonFacePressed: SkinRGBA(hex: "#2F2F37")!,
            buttonText: SkinRGBA(hex: "#D2D2DC")!,
            buttonTextActive: SkinRGBA(hex: "#4DFF9B")!,
            buttonSubtext: SkinRGBA(hex: "#9A9AA6")!,
            buttonSubtextActive: SkinRGBA(hex: "#3FA872")!,
            readoutBackground: SkinRGBA(hex: "#07120C")!,
            readoutInk: SkinRGBA(hex: "#4DFF9B")!,
            readoutInkDim: SkinRGBA(hex: "#3FA872")!,
            readoutInkIdle: SkinRGBA(hex: "#2F5C44")!,
            ledOn: SkinRGBA(hex: "#4DFF9B")!,
            ledOff: SkinRGBA(hex: "#23232A")!,
            visualizerOn: SkinRGBA(hex: "#4DFF9B")!,
            visualizerOff: SkinRGBA(hex: "#1E3A2A")!,
            accent: SkinRGBA(hex: "#4DFF9B")!,
            plate: SkinRGBA(hex: "#45454E")!,
            plateText: SkinRGBA(hex: "#D2D2DC")!,
            keyWall: SkinRGBA(hex: "#17171B")!,
            gaugeFace: SkinRGBA(hex: "#07120C")!,
            gaugeInk: SkinRGBA(hex: "#4DFF9B")!,
            needle: SkinRGBA(hex: "#4DFF9B")!
        ),
        metrics: SkinMetrics(
            width: 340,
            padding: 11,
            spacing: 11,
            bevel: 2,
            cornerRadius: 0,
            tileHeight: 142,
            titlebarHeight: 20,
            readoutPadding: 9,
            ledSize: 8,
            glowRadius: 7,
            tracking: 0.6,
            keyRelief: 5,
            indicatorDelay: 0
        ),
        fonts: SkinFonts(
            display: SkinFontSpec(family: "Geneva", size: 10, weight: .semibold),
            readout: SkinFontSpec(family: "Monaco", size: 11, monospaced: true),
            body: SkinFontSpec(family: "Geneva", size: 9.5)
        ),
        effects: SkinEffects(glow: true, scanlines: true, visualizer: true, uppercase: true),
        chrome: SkinChrome(screws: false, keyClick: false),
        layout: SkinLayout.stack
    )
}
