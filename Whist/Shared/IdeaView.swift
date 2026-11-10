import SwiftUI
import MessageUI
import UIKit

/// „Propune un joc”: utilizatorul descrie un joc românesc pe care l-ar vrea în aplicație,
/// iar textul pleacă pe email către dezvoltator (nu se salvează nimic în aplicație sau pe vreun server).
enum IdeaMail {
    static let address = "danieldraghicioiu@gmail.com"
}

/// Cardul din meniul principal care deschide formularul.
struct IdeaTile: View {
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "lightbulb.max.fill")
                .font(.system(size: 24, weight: .bold)).foregroundStyle(Color.black)
                .frame(width: 52, height: 52)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.gold))
            VStack(alignment: .leading, spacing: 3) {
                Text(L("idea.tile.title")).font(Theme.font(18, .heavy)).foregroundStyle(Theme.ink)
                Text(L("idea.tile.sub")).font(Theme.font(13, .medium)).foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.muted)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
            .strokeBorder(Theme.gold.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5])))
    }
}

struct IdeaView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @AppStorage("idea.name") private var author = ""
    @State private var title = ""
    @State private var players = 0
    @State private var details = ""
    @State private var showMail = false
    @State private var sent = false
    @State private var copied = false
    @FocusState private var focus: Field?

    private enum Field { case title, details, author }

    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedDetails: String { details.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSend: Bool { !trimmedTitle.isEmpty && trimmedDetails.count >= 10 }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backdrop
                if sent { thanks } else { form }
            }
            .navigationTitle(L("idea.tile.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(sent ? L("w.done") : L("idea.cancel")) { dismiss() }.font(Theme.font(17, .semibold))
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(L("w.done")) { focus = nil }.font(Theme.font(16, .bold))
                }
            }
        }
        .sheet(isPresented: $showMail) {
            MailComposer(to: IdeaMail.address, subject: subject, body: mailBody) { result in
                showMail = false
                if result == .sent { withAnimation(.spring) { sent = true } }
            }
            .ignoresSafeArea()
        }
    }

    // MARK: Formularul

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(L("idea.intro")).font(Theme.font(15, .medium)).foregroundStyle(Theme.ink.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 16) {
                    label(L("idea.f.title"))
                    TextField(L("idea.f.title.ph"), text: $title)
                        .focused($focus, equals: .title)
                        .textInputAutocapitalization(.sentences)
                        .submitLabel(.next).onSubmit { focus = .details }
                        .fieldStyle()

                    label(L("idea.f.players"))
                    Pills(options: [0, 2, 3, 4, 6], selection: $players) { n in
                        switch n {
                        case 0: return L("idea.players.any")
                        case 6: return "5+"
                        default: return "\(n)"
                        }
                    }

                    label(L("idea.f.details"))
                    ZStack(alignment: .topLeading) {
                        if details.isEmpty {
                            Text(L("idea.f.details.ph")).font(Theme.font(16, .regular)).foregroundStyle(Theme.muted)
                                .padding(.horizontal, 18).padding(.vertical, 20)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: $details)
                            .focused($focus, equals: .details)
                            .font(Theme.font(16, .regular)).foregroundStyle(Theme.ink)
                            .scrollContentBackground(.hidden)
                            .padding(10)
                            .frame(minHeight: 170)
                    }
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.soft))

                    label(L("idea.f.author"))
                    TextField(L("idea.f.author.ph"), text: $author)
                        .focused($focus, equals: .author)
                        .textInputAutocapitalization(.words).autocorrectionDisabled()
                        .submitLabel(.done)
                        .fieldStyle()
                }
                .panel(padding: 18)

                Button {
                    focus = nil
                    send()
                } label: {
                    Label(L("idea.send"), systemImage: "paperplane.fill")
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!canSend)
                .opacity(canSend ? 1 : 0.5)

                Text(copied ? L("idea.copied", IdeaMail.address) : L("idea.note", IdeaMail.address))
                    .font(Theme.font(12, .medium)).foregroundStyle(copied ? Theme.gold : Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 24)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var thanks: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 64)).foregroundStyle(Theme.gold)
            Text(L("idea.thanks.t")).font(Theme.display(34)).foregroundStyle(Theme.ink)
            Text(L("idea.thanks.x")).font(Theme.font(16, .medium)).foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
            Button(L("idea.another")) {
                withAnimation(.spring) { title = ""; details = ""; players = 0; sent = false; copied = false }
            }
            .buttonStyle(SecondaryButtonStyle())
            .padding(.top, 8)
        }
        .padding(30)
    }

    private func label(_ s: String) -> some View {
        Text(s.uppercased()).font(.system(size: 12, weight: .heavy)).kerning(0.6).foregroundStyle(Theme.muted)
    }

    // MARK: Trimiterea

    private var subject: String { L("idea.mail.subject", trimmedTitle) }

    private var mailBody: String {
        let playersText = players == 0 ? L("idea.players.any") : (players == 6 ? "5+" : "\(players)")
        let name = author.trimmingCharacters(in: .whitespacesAndNewlines)
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let lang = Locale.current.language.languageCode?.identifier ?? ""
        return [
            "\(L("idea.f.title")): \(trimmedTitle)",
            "\(L("idea.f.players")): \(playersText)",
            "",
            trimmedDetails,
            "",
            name.isEmpty ? nil : "\(L("idea.f.author")): \(name)",
            "— \(L("idea.mail.footer")) \(version) · \(lang)"
        ].compactMap { $0 }.joined(separator: "\n")
    }

    private func send() {
        Haptics.tap()
        if MFMailComposeViewController.canSendMail() {
            showMail = true
            return
        }
        // Fără cont în Mail: încercăm aplicația de email implicită (Gmail, Outlook…) prin mailto:
        var c = URLComponents()
        c.scheme = "mailto"
        c.path = IdeaMail.address
        c.queryItems = [URLQueryItem(name: "subject", value: subject), URLQueryItem(name: "body", value: mailBody)]
        if let url = c.url {
            openURL(url) { ok in
                if ok {
                    withAnimation(.spring) { sent = true }
                } else {
                    // nicio aplicație de email: copiem textul, ca să-l poată trimite oricum
                    UIPasteboard.general.string = "\(IdeaMail.address)\n\(subject)\n\n\(mailBody)"
                    withAnimation { copied = true }
                }
            }
        }
    }
}

private extension View {
    func fieldStyle() -> some View {
        self.font(Theme.font(17, .semibold)).foregroundStyle(Theme.ink)
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.soft))
    }
}

/// Fereastra de email a sistemului.
private struct MailComposer: UIViewControllerRepresentable {
    let to: String
    let subject: String
    let body: String
    let onFinish: (MFMailComposeResult) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        vc.setToRecipients([to])
        vc.setSubject(subject)
        vc.setMessageBody(body, isHTML: false)
        return vc
    }

    func updateUIViewController(_ vc: MFMailComposeViewController, context: Context) {}

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onFinish: (MFMailComposeResult) -> Void
        init(onFinish: @escaping (MFMailComposeResult) -> Void) { self.onFinish = onFinish }
        func mailComposeController(_ controller: MFMailComposeViewController,
                                   didFinishWith result: MFMailComposeResult, error: Error?) {
            onFinish(result)
        }
    }
}
