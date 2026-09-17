import SkinKit
import SwiftUI
import UniformTypeIdentifiers

struct SkinsSettingsView: View {

    let model: AppModel
    @State private var failure: String?

    var body: some View {
        VStack(spacing: 0) {
            List(
                selection: Binding(
                    get: { model.skins.selectedID },
                    set: { model.skins.selectedID = $0 ?? model.skins.selectedID }
                )
            ) {
                ForEach(model.skins.skins) { skin in
                    SkinRow(skin: skin)
                        .tag(skin.id)
                }
            }
            .listStyle(.inset)

            Divider()

            HStack(spacing: 8) {
                Button("Import…") { importSkin() }
                Button("Reveal Folder") { model.skins.revealUserSkinsFolder() }
                Button("Reload") { model.skins.reload() }

                Spacer()

                Button("Delete", role: .destructive) { deleteSelected() }
                    .disabled(model.skins.current.isBuiltIn)
            }
            .padding(12)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                if let failure {
                    Text(failure).font(.caption).foregroundStyle(.red)
                }
                ForEach(model.skins.problems, id: \.self) { problem in
                    Label(problem, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                Text(
                    "Skins are folders ending in .mccskin. Saving one reloads the panel live — the folder's README documents every token."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
    }

    private func importSkin() {
        let panel = NSOpenPanel()
        panel.title = "Import Skin"
        panel.prompt = "Import"
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose a .mccskin folder or a skin .json file."

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try model.skins.importSkin(from: url)
            failure = nil
        } catch {
            failure = error.localizedDescription
        }
    }

    private func deleteSelected() {
        do {
            try model.skins.delete(model.skins.current)
            failure = nil
        } catch {
            failure = error.localizedDescription
        }
    }
}

private struct SkinRow: View {

    let skin: Skin

    var body: some View {
        HStack(spacing: 10) {
            SkinSwatch(skin: skin)

            VStack(alignment: .leading, spacing: 2) {
                Text(skin.name).fontWeight(.medium)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if skin.isBuiltIn {
                Text("Built in")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }
        }
        .padding(.vertical, 3)
    }

    private var subtitle: String {
        [skin.notes, skin.author.isEmpty ? "" : "by " + skin.author]
            .filter { !$0.isEmpty }
            .joined(separator: "  ·  ")
    }
}

/// A miniature of the skin's chassis, readout and lamp, so the list shows the skin
/// rather than only naming it.
private struct SkinSwatch: View {

    let skin: Skin

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(skin.colors.panel.color)
            VStack(spacing: 2) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(skin.colors.readoutBackground.color)
                    .overlay(
                        RoundedRectangle(cornerRadius: 1)
                            .fill(skin.colors.readoutInk.color)
                            .frame(height: 2)
                            .padding(.horizontal, 3),
                        alignment: .center
                    )
                    .frame(height: 10)
                HStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 1).fill(skin.colors.buttonFace.color)
                    RoundedRectangle(cornerRadius: 1).fill(skin.colors.buttonFacePressed.color)
                        .overlay(Circle().fill(skin.colors.ledOn.color).frame(width: 3, height: 3))
                }
                .frame(height: 12)
            }
            .padding(3)
        }
        .frame(width: 40, height: 34)
        .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(.separator))
    }
}
