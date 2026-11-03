import SwiftUI
import GameKit

/// Date despre aplicație folosite în Setări. Înlocuiește adresele cu ale tale înainte de publicare.
enum AppInfo {
    static let privacyURL = URL(string: "https://puiutpavel-dot.github.io/whist-legal/privacy.html")!
    static let supportURL = URL(string: "https://puiutpavel-dot.github.io/whist-legal/")!

    static var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}

struct SettingsView: View {
    @ObservedObject var game: GameViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @AppStorage(SettingsKey.sound) private var sound = true
    @AppStorage(SettingsKey.music) private var music = true
    @AppStorage(SettingsKey.haptics) private var haptics = true
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(isOn: $sound) { Label("Sound effects", systemImage: "speaker.wave.2.fill") }
                    Toggle(isOn: $music) { Label("Music", systemImage: "music.note") }
                    Toggle(isOn: $haptics) { Label("Vibration", systemImage: "iphone.radiowaves.left.and.right") }
                } header: {
                    Text("Sound")
                }

                Section {
                    Text("Avioane uses your iPhone's language. To pick a different language just for this app, open its page in iOS Settings.")
                        .font(.footnote)
                        .foregroundStyle(AvTheme.textDim)
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    } label: {
                        Label("Open iOS Settings", systemImage: "globe")
                    }
                } header: {
                    Text("Language")
                }


                Section {
                    Button { openURL(AppInfo.privacyURL) } label: {
                        Label("Privacy policy", systemImage: "hand.raised.fill")
                    }
                    Button { openURL(AppInfo.supportURL) } label: {
                        Label("Support", systemImage: "questionmark.circle")
                    }
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(AppInfo.version).foregroundStyle(AvTheme.textDim).monospacedDigit()
                    }
                } header: {
                    Text("About")
                }

                Section {
                    Button(role: .destructive) { confirmReset = true } label: {
                        Label("Reset statistics", systemImage: "arrow.counterclockwise")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AvTheme.bg)
            .tint(AvTheme.gold)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .onChange(of: music) { _ in SoundManager.shared.updateMusic() }
            .confirmationDialog("Reset all statistics?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Reset", role: .destructive) { game.resetStats() }
                Button("Cancel", role: .cancel) {}
            }
        }
        .preferredColorScheme(.dark)
    }
}
