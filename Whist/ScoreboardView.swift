import SwiftUI

struct ScoreboardView: View {
    @ObservedObject var engine: GameEngine
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView([.vertical, .horizontal]) {
                Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                    GridRow {
                        header("Cărți").gridCellColumns(1)
                        ForEach(engine.players) { p in
                            header(p.name).gridCellColumns(2)
                        }
                    }
                    GridRow {
                        sub("")
                        ForEach(engine.players) { _ in
                            sub("Lic.")
                            sub("Pct.")
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
            .navigationTitle("Tabela de scor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Gata") { dismiss() }.font(Theme.font(17, .bold))
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

    private let sections: [RuleItem] = [
        RuleItem("person.3.fill", "Jucători și pachet",
         "3–6 jucători, fiecare pe cont propriu. Se folosesc câte 8 cărți pentru fiecare jucător: 24 la 3 jucători, 32 la 4, până la 48 la 6. Ordinea cărților: A, K, Q, J, 10, 9 și așa mai departe."),
        RuleItem("square.stack.3d.up.fill", "Mâinile",
         "În formatul 1-8-1 se joacă întâi atâtea mâini de o carte câți jucători sunt, apoi 2, 3 … 7, apoi atâtea mâini de 8 câți jucători sunt, apoi înapoi la 1. Formatul 8-1-8 face invers. Cel care împarte se schimbă după fiecare mână."),
        RuleItem("suit.heart.fill", "Atuul",
         "După împărțire, următoarea carte din pachet se întoarce și dă culoarea de atu. La mâinile de 8 cărți nu mai rămâne nicio carte, deci se joacă fără atu."),
        RuleItem("number.circle.fill", "Licitația",
         "Începând din stânga celui care împarte, fiecare spune câte levate crede că va lua. Ultimul (cel care a împărțit) nu are voie să aleagă numărul care ar face suma licitațiilor egală cu numărul de cărți din mână."),
        RuleItem("hand.tap.fill", "Jocul",
         "Deschide jucătorul din stânga celui care împarte. Ești obligat să răspunzi la culoare. Dacă nu ai culoarea, ești obligat să tai cu atu. Dacă nu ai nici atu, dai orice carte. Levata o ia cel mai mare atu sau, fără atu, cea mai mare carte din culoarea cerută. Câștigătorul deschide următoarea levată."),
        RuleItem("star.fill", "Punctajul",
         "Dacă iei exact cât ai licitat: 5 puncte + câte 1 pentru fiecare levată. Dacă iei mai multe sau mai puține, pierzi câte 1 punct pentru fiecare levată de diferență."),
        RuleItem("eye.slash.fill", "Cartea pe frunte (opțional)",
         "La ultima serie de mâini de o carte nu-ți vezi cartea: o ții „pe frunte”. Vezi cărțile celorlalți și licitezi după ele și după ce au spus ei."),
        RuleItem("flame.fill", "Premii (opțional)",
         "Cu premiile activate: 5 contracte reușite la rând aduc +10 puncte, 5 ratate la rând −10. Mâinile de o carte nu se pun la serii.")
    ]

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
            .navigationTitle("Reguli")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Gata") { dismiss() }.font(Theme.font(17, .bold))
                }
            }
        }
    }
}
