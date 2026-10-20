import SwiftUI

struct RemiRulesView: View {
    @Environment(\.dismiss) private var dismiss

    private let sections: [RuleSection] = [
        RuleSection(icon: "shippingbox.fill", title: L("rules.s1"), items: [L("rules.s1.1"), L("rules.s1.2"), L("rules.s1.3"), L("rules.s1.4")]),
        RuleSection(icon: "square.stack.3d.up.fill", title: L("rules.s2"), items: [L("rules.s2.1"), L("rules.s2.2"), L("rules.s2.3")]),
        RuleSection(icon: "arrow.triangle.2.circlepath", title: L("rules.s3"), items: [L("rules.s3.1"), L("rules.s3.2"), L("rules.s3.3")]),
        RuleSection(icon: "star.fill", title: L("rules.s4"), items: [L("rules.s4.1"), L("rules.s4.2"), L("rules.s4.3")]),
        RuleSection(icon: "hand.point.up.left.fill", title: L("rules.s5"), items: [L("rules.s5.1"), L("rules.s5.2"), L("rules.s5.3"), L("rules.s5.4")]),
        RuleSection(icon: "exclamationmark.triangle.fill", title: L("rules.s6"), items: [L("rules.s6.1"), L("rules.s6.2"), L("rules.s6.3")]),
        RuleSection(icon: "number.circle.fill", title: L("rules.s7"), items: [L("rules.s7.1"), L("rules.s7.2"), L("rules.s7.3")]),
        RuleSection(icon: "trophy.fill", title: L("rules.s8"), items: [L("rules.s8.1"), L("rules.s8.2"), L("rules.s8.3"), L("rules.s8.4"), L("rules.s8.5")])
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(sections) { section in
                        VStack(alignment: .leading, spacing: 10) {
                            Label(section.title, systemImage: section.icon)
                                .font(.system(size: 17, weight: .heavy, design: .serif))
                                .foregroundStyle(RemiTheme.gold)
                            ForEach(section.items, id: \.self) { item in
                                HStack(alignment: .top, spacing: 8) {
                                    Circle().fill(RemiTheme.crimson).frame(width: 5, height: 5).padding(.top, 7)
                                    Text(item)
                                        .font(.system(size: 15))
                                        .foregroundStyle(.white.opacity(0.9))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(RemiTheme.panel))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(L("rules.notIncluded"))
                            .font(.footnote.bold()).foregroundStyle(RemiTheme.textDim)
                        Text(L("rules.notIncludedText"))
                            .font(.footnote).foregroundStyle(RemiTheme.textDim)
                        Link(L("rules.source"),
                             destination: URL(string: "https://www.cumsejoaca.ro/reguli-si-regulamente/reguli-de-joc-pentru-remi-remy-rummy-etalat/")!)
                            .font(.footnote.bold())
                            .tint(RemiTheme.gold)
                    }
                    .padding(.horizontal, 4)
                }
                .padding(16)
            }
            .background(RemiTheme.background.ignoresSafeArea())
            .navigationTitle(L("rules.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("rules.done")) { dismiss() }.tint(RemiTheme.gold)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct RuleSection: Identifiable {
    let icon: String
    let title: String
    let items: [String]
    var id: String { title }
}
