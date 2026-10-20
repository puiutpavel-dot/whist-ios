import SwiftUI

struct ScoreboardView: View {
    @ObservedObject var engine: GameEngine
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView([.vertical, .horizontal]) {
                Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                    GridRow {
                        header(L("w.sb.cards")).gridCellColumns(1)
                        ForEach(engine.players) { p in
                            header(p.name).gridCellColumns(2)
                        }
                    }
                    GridRow {
                        sub("")
                        ForEach(engine.players) { _ in
                            sub(L("w.sb.bid"))
                            sub(L("w.sb.pts"))
                        }
                    }
                    ForEach(engine.handSizes.indices, id: \.self) { i in
                        let rec = i < engine.history.count ? engine.history[i] : nil
                        let isCurrent = i == engine.handIndex && rec == nil
                        GridRow {
                            let bg = isCurrent ? Theme.soft : (i.isMultiple(of: 2) ? Theme.surface : Theme.bg)
                            Text(trumpLabel(size: engine.handSizes[i], rec: rec))
                                .font(Theme.font(14, .bold))
                                .foregroundStyle(rec == nil ? Theme.muted : Theme.ink)
                                .frame(width: 58, height: 34)
                                .background(bg)
                            ForEach(engine.players) { p in
                                if let e = rec?.entries[p.id] {
                                    cell("\(e.bid)", color: Theme.muted, bg: bg)
                                    cell("\(e.total)", color: e.made ? Theme.green : Theme.red, bold: true, bg: bg)
                                } else if isCurrent {
                                    cell(p.bid.map { "\($0)" } ?? "·", color: Theme.primary, bg: bg)
                                    cell("", color: Theme.muted, bg: bg)
                                } else {
                                    cell("", color: Theme.muted, bg: bg)
                                    cell("", color: Theme.muted, bg: bg)
                                }
                            }
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(16)
            }
            .background(Theme.bg)
            .navigationTitle(L("w.scores"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("w.done")) { dismiss() }.font(Theme.font(17, .bold))
                }
            }
        }
    }

    private func trumpLabel(size: Int, rec: HandRecord?) -> String {
        guard let t = rec?.trump else { return "\(size)" }
        return "\(size) \(t.suit.symbol)"
    }

    private func header(_ s: String) -> some View {
        Text(s.uppercased()).font(.system(size: 13, weight: .heavy)).foregroundStyle(.white)
            .lineLimit(1)
            .frame(maxWidth: .infinity, minHeight: 36)
            .background(Theme.accent)
    }

    private func sub(_ s: String) -> some View {
        Text(s).font(Theme.font(11, .semibold)).foregroundStyle(Theme.primary)
            .frame(width: s.isEmpty ? 58 : 46, height: 24)
            .background(Theme.soft)
    }

    private func cell(_ s: String, color: Color, bold: Bool = false, bg: Color) -> some View {
        Text(s).font(Theme.font(14, bold ? .bold : .medium)).foregroundStyle(color)
            .frame(width: 46, height: 34)
            .background(bg)
    }
}

struct RulesView: View {
    @Environment(\.dismiss) private var dismiss

    private struct RuleItem: Identifiable {
        let icon: String, title: String, text: String
        var id: String { title }
        init(_ icon: String, _ title: String, _ text: String) { self.icon = icon; self.title = title; self.text = text }
    }

    private var sections: [RuleItem] { [
        RuleItem("person.3.fill", L("w.r1.t"), L("w.r1.x")),
        RuleItem("square.stack.3d.up.fill", L("w.r2.t"), L("w.r2.x")),
        RuleItem("suit.heart.fill", L("w.r3.t"), L("w.r3.x")),
        RuleItem("number.circle.fill", L("w.r4.t"), L("w.r4.x")),
        RuleItem("hand.tap.fill", L("w.r5.t"), L("w.r5.x")),
        RuleItem("star.fill", L("w.r6.t"), L("w.r6.x")),
        RuleItem("eye.slash.fill", L("w.r7.t"), L("w.r7.x")),
        RuleItem("flame.fill", L("w.r8.t"), L("w.r8.x")),
        RuleItem("lightbulb.fill", L("w.r9.t"), L("w.r9.x")),
        RuleItem("target", L("w.r10.t"), L("w.r10.x")),
        RuleItem("book.closed.fill", L("w.r11.t"), L("w.r11.x"))
    ] }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    ForEach(sections) { sec in
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: sec.icon)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(Theme.primary)
                                .frame(width: 40, height: 40)
                                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.soft))
                            VStack(alignment: .leading, spacing: 6) {
                                Text(sec.title).font(Theme.font(17, .bold)).foregroundStyle(Theme.ink)
                                Text(sec.text).font(Theme.font(15, .regular)).foregroundStyle(Theme.ink.opacity(0.8))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                        .panel(padding: 16)
                    }
                }
                .padding(16)
            }
            .background(Theme.bg)
            .navigationTitle(L("w.rules.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("w.done")) { dismiss() }.font(Theme.font(17, .bold))
                }
            }
        }
    }
}
