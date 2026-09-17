import Foundation

public extension AppConfig {

    /// The config the app ships with, and the one Duplicate starts from.
    ///
    /// Deliberately minimal and entirely sandbox-safe: it is what a first-run user sees,
    /// and what the App Store build can perform in full.
    static let standard = AppConfig(
        id: "default",
        name: "Default",
        author: "Mac Command Center",
        notes: "Keep the Mac awake while work is running.",
        isBuiltIn: true,
        groups: [
            ConfigGroup(
                id: "power",
                title: "Power",
                commands: [
                    ConfigCommand(
                        id: "keep-awake",
                        title: "Keep Awake",
                        summary: "Normal sleep settings apply.",
                        icon: "cup.and.saucer.fill",
                        options: [
                            ConfigOption(
                                id: "display-on",
                                title: "Awake + Display On",
                                subtitle: "Nothing sleeps, screen stays lit",
                                icon: "sun.max.fill",
                                action: .keepAwake(mode: .systemAndDisplay)
                            ),
                            ConfigOption(
                                id: "display-off",
                                title: "Awake, Display Off",
                                subtitle: "Mac runs on, screen may sleep",
                                icon: "moon.zzz.fill",
                                action: .keepAwake(mode: .systemOnly)
                            ),
                        ]
                    )
                ]
            )
        ]
    )
}
